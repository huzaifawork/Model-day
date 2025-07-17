import 'package:flutter/foundation.dart';
import '../models/job.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class JobsService {
  static const String _collectionName = 'jobs';

  static Future<List<Job>> list() async {
    try {
      debugPrint(
          '🔍 JobsService.list() - Fetching jobs from collection: $_collectionName');
      debugPrint(
          '🔍 JobsService.list() - User authenticated: ${FirebaseServiceTemplate.isAuthenticated}');
      debugPrint(
          '🔍 JobsService.list() - Current user ID: ${FirebaseServiceTemplate.currentUserId}');

      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🔍 JobsService.list() - Retrieved ${documents.length} documents');

      final jobs = documents.map<Job>((doc) {
        debugPrint('🔍 JobsService.list() - Processing document: ${doc['id']}');
        return Job.fromJson(doc);
      }).toList();

      debugPrint(
          '✅ JobsService.list() - Successfully converted ${jobs.length} jobs');
      return jobs;
    } catch (e) {
      debugPrint('❌ JobsService.list() - Error fetching jobs: $e');
      return [];
    }
  }

  static Future<Job?> get(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Job.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching job: $e');
      return null;
    }
  }

  static Future<Job?> create(Map<String, dynamic> data) async {
    try {
      debugPrint('🔍 JobsService.create() - Creating job with data: $data');
      debugPrint(
          '🔍 JobsService.create() - User authenticated: ${FirebaseServiceTemplate.isAuthenticated}');

      final docId =
          await FirebaseServiceTemplate.createDocument(_collectionName, data);
      debugPrint('🔍 JobsService.create() - Created document with ID: $docId');

      if (docId != null) {
        final job = await get(docId);
        debugPrint(
            '✅ JobsService.create() - Successfully created job: ${job?.id}');

        // Sync to Google Calendar in background
        if (job != null) {
          debugPrint('🔄 Starting Google Calendar sync for job...');
          _syncJobToGoogleCalendar(job, docId);
        } else {
          debugPrint('❌ Cannot sync to Google Calendar - job is null');
        }

        return job;
      }
      debugPrint('❌ JobsService.create() - Failed to create document');
      return null;
    } catch (e) {
      debugPrint('❌ JobsService.create() - Error creating job: $e');
      return null;
    }
  }

  static Future<Job?> update(String id, Map<String, dynamic> data) async {
    try {
      debugPrint('📅 JobsService.update() - Updating job $id with data: $data');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, data);
      if (success) {
        final updatedJob = await get(id);

        // Sync update to Google Calendar if the job was previously synced
        if (updatedJob != null) {
          _syncJobUpdateToGoogleCalendar(updatedJob, id);
        }

        return updatedJob;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating job: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 JobsService.delete() - Deleting job $id');

      // Get the existing job AND document data to check for Google Calendar sync before deletion
      final existingJob = await get(id);
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);

      String? googleCalendarEventId;
      if (doc != null) {
        googleCalendarEventId = doc['google_calendar_event_id'] as String?;
        debugPrint('🔍 Found Google Calendar event ID: $googleCalendarEventId');
      }

      // Delete from Firestore
      final success =
          await FirebaseServiceTemplate.deleteDocument(_collectionName, id);

      // Sync deletion to Google Calendar if the job was previously synced
      if (success &&
          existingJob != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncJobDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingJob.clientName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting job: $e');
      return false;
    }
  }

  static Future<List<Job>> getByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, startDate, endDate,
          dateField: 'date');
      return documents.map<Job>((doc) => Job.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching jobs by date range: $e');
      return [];
    }
  }

  static Future<List<Job>> search(String query) async {
    try {
      final documents = await FirebaseServiceTemplate.searchDocuments(
          _collectionName, 'title', query);
      return documents.map<Job>((doc) => Job.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error searching jobs: $e');
      return [];
    }
  }

  // Additional methods for compatibility
  static Future<List<Job>> getJobs() async {
    return await list();
  }

  static Future<bool> deleteJob(String id) async {
    return await delete(id);
  }

  /// Sync job to Google Calendar in background
  static Future<void> _syncJobToGoogleCalendar(Job job, String docId) async {
    try {
      debugPrint('📅 Syncing job to Google Calendar: ${job.clientName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Convert Job to Event model for Google Calendar
      final event = Event(
        type: EventType.job,
        clientName: job.clientName,
        date: DateTime.parse(job.date),
        startTime: job.time,
        endTime: job.endTime,
        location: job.location,
        notes: job.notes,
        dayRate: job.rate,
        currency: job.currency,
      );

      // Create event in Google Calendar
      final calendarEventId =
          await GoogleCalendarService.createEventInGoogleCalendar(event);

      if (calendarEventId != null) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'google_calendar_event_id': calendarEventId,
          'synced_to_google_calendar': true,
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Job synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync job to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing job to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync job update to Google Calendar in background
  static Future<void> _syncJobUpdateToGoogleCalendar(
      Job job, String docId) async {
    try {
      debugPrint('📅 Syncing job update to Google Calendar: ${job.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ Job document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if job was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - skipping update sync');

        // Try to find Google Calendar event ID by searching for events with matching title
        debugPrint('🔍 Searching for Google Calendar event by title...');
        final foundEventId = await _findGoogleCalendarEventByTitle(job);

        if (foundEventId != null) {
          debugPrint('✅ Found Google Calendar event ID: $foundEventId');

          // Update Firestore with the found Google Calendar event ID
          await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
            'google_calendar_event_id': foundEventId,
            'synced_to_google_calendar': true,
            'last_sync_date': DateTime.now().toIso8601String(),
          });

          // Now proceed with the update using the found event ID
          final success =
              await GoogleCalendarService.updateEventInGoogleCalendar(
                  foundEventId, _jobToEvent(job));

          if (success) {
            debugPrint('✅ Job update synced to Google Calendar: $foundEventId');
          } else {
            debugPrint('❌ Failed to sync job update to Google Calendar');
          }
          return;
        } else {
          debugPrint(
              '❌ Could not find Google Calendar event - skipping update sync');
          return;
        }
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert Job to Event model for Google Calendar
      final event = _jobToEvent(job);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Job update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync job update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing job update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync job deletion to Google Calendar in background with event ID
  static Future<void> _syncJobDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint('📅 Syncing job deletion to Google Calendar: $clientName');

      // Check if we have a valid Google Calendar event ID
      if (googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID provided - skipping delete sync');
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping delete sync');
        return;
      }

      // Delete event from Google Calendar
      final success = await GoogleCalendarService.deleteEventInGoogleCalendar(
          googleCalendarEventId);

      if (success) {
        debugPrint(
            '✅ Job deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync job deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing job deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert Job to Event model for Google Calendar
  static Event _jobToEvent(Job job) {
    return Event(
      type: EventType.job,
      clientName: job.clientName,
      date: DateTime.parse(job.date),
      startTime: job.time,
      endTime: job.endTime,
      location: job.location,
      notes: job.notes,
      dayRate: job.rate,
      currency: job.currency,
    );
  }

  /// Find Google Calendar event by searching for events with matching title
  static Future<String?> _findGoogleCalendarEventByTitle(Job job) async {
    try {
      debugPrint(
          '🔍 Searching for Google Calendar event with title: Job - ${job.clientName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - cannot search for events');
        return null;
      }

      // Search for events with matching title
      final event = _jobToEvent(job);
      final foundEventId =
          await GoogleCalendarService.findEventByTitle(event.title, event.date);

      if (foundEventId != null) {
        debugPrint('✅ Found Google Calendar event: $foundEventId');
        return foundEventId;
      } else {
        debugPrint('❌ No matching Google Calendar event found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error searching for Google Calendar event: $e');
      return null;
    }
  }
}
