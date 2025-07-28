import 'package:flutter/foundation.dart';
import '../models/ai_job.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class AiJobsService {
  static const String _collectionName = 'ai_jobs';

  static Future<List<AiJob>> list() async {
    try {
      debugPrint('🤖 AiJobsService.list() - Fetching AI jobs...');
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🤖 AiJobsService.list() - Found ${documents.length} documents');
      final aiJobs =
          documents.map<AiJob>((doc) => AiJob.fromJson(doc)).toList();
      debugPrint('🤖 AiJobsService.list() - Parsed ${aiJobs.length} AI jobs');
      return aiJobs;
    } catch (e) {
      debugPrint('❌ Error fetching AI jobs: $e');
      return [];
    }
  }

  static Future<AiJob?> getById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return AiJob.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching AI job: $e');
      return null;
    }
  }

  static Future<AiJob?> create(Map<String, dynamic> aiJobData) async {
    try {
      debugPrint(
          '🤖 AiJobsService.create() - Creating AI job with data: $aiJobData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, aiJobData);
      debugPrint(
          '🤖 AiJobsService.create() - Created document with ID: $docId');
      if (docId != null) {
        final aiJob = await getById(docId);
        debugPrint(
            '🤖 AiJobsService.create() - Retrieved AI job: ${aiJob?.clientName}');

        // Sync to Google Calendar in background
        if (aiJob != null) {
          _syncAiJobToGoogleCalendar(aiJob, docId);
        }

        return aiJob;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating AI job: $e');
      return null;
    }
  }

  static Future<AiJob?> update(
      String id, Map<String, dynamic> aiJobData) async {
    try {
      debugPrint('📅 AiJobsService.update() - Updating AI job $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, aiJobData);
      if (success) {
        final updatedAiJob = await getById(id);

        // Sync update to Google Calendar if the AI job was previously synced
        if (updatedAiJob != null) {
          _syncAiJobUpdateToGoogleCalendar(updatedAiJob, id);
        }

        return updatedAiJob;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating AI job: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 AiJobsService.delete() - Deleting AI job $id');

      // Get the existing AI job AND document data to check for Google Calendar sync before deletion
      final existingAiJob = await getById(id);
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

      // Sync deletion to Google Calendar if the AI job was previously synced
      if (success &&
          existingAiJob != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncAiJobDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingAiJob.clientName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting AI job: $e');
      return false;
    }
  }

  static Future<List<AiJob>> getByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, startDate, endDate,
          dateField: 'date');
      return documents.map<AiJob>((doc) => AiJob.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching AI jobs by date range: $e');
      return [];
    }
  }

  static Future<List<AiJob>> search(String query) async {
    try {
      final documents = await FirebaseServiceTemplate.searchDocuments(
          _collectionName, 'title', query);
      return documents.map<AiJob>((doc) => AiJob.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error searching AI jobs: $e');
      return [];
    }
  }

  /// Sync AI job to Google Calendar in background
  static Future<void> _syncAiJobToGoogleCalendar(
      AiJob aiJob, String docId) async {
    try {
      debugPrint('📅 Syncing AI job to Google Calendar: ${aiJob.clientName}');

      // Convert AiJob to Event model for Google Calendar
      final event = Event(
        type: EventType.other,
        clientName: aiJob.clientName,
        date: aiJob.date ?? DateTime.now(),
        startTime: aiJob.time,
        location: aiJob.location,
        notes:
            '${aiJob.type?.replaceAll('_', ' ').toUpperCase() ?? 'AI Job'}\n\n'
            '${aiJob.description ?? ''}\n\n'
            'Rate: ${aiJob.rate != null ? '${aiJob.rate} ${aiJob.currency}' : 'TBD'}\n'
            'Status: ${aiJob.status?.toUpperCase() ?? 'PENDING'}\n'
            'Payment: ${aiJob.paymentStatus?.toUpperCase() ?? 'UNPAID'}\n\n'
            '${aiJob.notes ?? ''}',
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
        debugPrint('✅ AI job synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync AI job to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing AI job to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync AI job update to Google Calendar in background
  static Future<void> _syncAiJobUpdateToGoogleCalendar(
      AiJob aiJob, String docId) async {
    try {
      debugPrint(
          '📅 Syncing AI job update to Google Calendar: ${aiJob.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ AI job document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if AI job was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - creating new event instead');

        // Create a new Google Calendar event for this AI job
        _syncAiJobToGoogleCalendar(aiJob, docId);
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert AiJob to Event model for Google Calendar
      final event = _aiJobToEvent(aiJob);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ AI job update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync AI job update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing AI job update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync AI job deletion to Google Calendar in background with event ID
  static Future<void> _syncAiJobDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint('📅 Syncing AI job deletion to Google Calendar: $clientName');

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
            '✅ AI job deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync AI job deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing AI job deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert AiJob to Event model for Google Calendar
  static Event _aiJobToEvent(AiJob aiJob) {
    return Event(
      type: EventType.job, // Use job type for AI jobs
      clientName: aiJob.clientName,
      date: aiJob.date, // AiJob.date is already DateTime
      startTime: aiJob.time,
      endTime: null, // AiJob model doesn't have endTime
      location: aiJob.location,
      notes: aiJob.notes,
      dayRate: aiJob.rate,
      currency: aiJob.currency,
    );
  }
}
