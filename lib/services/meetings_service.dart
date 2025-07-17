import 'package:flutter/foundation.dart';
import '../models/meeting.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class MeetingsService {
  static const String _collectionName = 'meetings';

  static Future<List<Meeting>> list() async {
    try {
      debugPrint('🏢 MeetingsService.list() - Fetching meetings...');
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🏢 MeetingsService.list() - Found ${documents.length} documents');
      final meetings =
          documents.map<Meeting>((doc) => Meeting.fromJson(doc)).toList();
      debugPrint(
          '🏢 MeetingsService.list() - Parsed ${meetings.length} meetings');
      return meetings;
    } catch (e) {
      debugPrint('❌ Error fetching meetings: $e');
      return [];
    }
  }

  static Future<Meeting?> create(Map<String, dynamic> meetingData) async {
    try {
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, meetingData);
      if (docId != null) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        if (doc != null) {
          final meeting = Meeting.fromJson(doc);

          // Sync to Google Calendar in background
          _syncMeetingToGoogleCalendar(meeting, docId);

          return meeting;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return null;
    }
  }

  static Future<Meeting?> update(
      String id, Map<String, dynamic> meetingData) async {
    try {
      debugPrint('📅 MeetingsService.update() - Updating meeting $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, meetingData);
      if (success) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, id);
        if (doc != null) {
          final updatedMeeting = Meeting.fromJson(doc);

          // Sync update to Google Calendar if the meeting was previously synced
          _syncMeetingUpdateToGoogleCalendar(updatedMeeting, id);

          return updatedMeeting;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error updating meeting: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 MeetingsService.delete() - Deleting meeting $id');

      // Get the existing meeting AND document data to check for Google Calendar sync before deletion
      final existingMeeting = await getMeetingById(id);
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

      // Sync deletion to Google Calendar if the meeting was previously synced
      if (success &&
          existingMeeting != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncMeetingDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingMeeting.clientName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting meeting: $e');
      return false;
    }
  }

  static Future<Meeting?> getMeetingById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Meeting.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching meeting: $e');
      return null;
    }
  }

  static Future<Meeting?> updateMeeting(
      String id, Map<String, dynamic> meetingData) async {
    try {
      debugPrint(
          '📅 MeetingsService.updateMeeting() - Updating meeting $id with data: $meetingData');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, meetingData);
      debugPrint(
          '📅 MeetingsService.updateMeeting() - Update success: $success');

      if (success) {
        final updatedMeeting = await getMeetingById(id);
        debugPrint(
            '📅 MeetingsService.updateMeeting() - Retrieved updated meeting: ${updatedMeeting?.clientName}');

        // Sync update to Google Calendar if the meeting was previously synced
        if (updatedMeeting != null) {
          debugPrint(
              '📅 MeetingsService.updateMeeting() - Starting Google Calendar sync...');
          _syncMeetingUpdateToGoogleCalendar(updatedMeeting, id);
        } else {
          debugPrint(
              '❌ MeetingsService.updateMeeting() - No updated meeting found');
        }

        return updatedMeeting;
      } else {
        debugPrint('❌ MeetingsService.updateMeeting() - Update failed');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error updating meeting: $e');
      return null;
    }
  }

  static Future<Meeting?> createMeeting(
      Map<String, dynamic> meetingData) async {
    try {
      debugPrint(
          '🏢 MeetingsService.createMeeting() - Creating meeting with data: $meetingData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, meetingData);
      debugPrint(
          '🏢 MeetingsService.createMeeting() - Created document with ID: $docId');
      if (docId != null) {
        final meeting = await getMeetingById(docId);
        debugPrint(
            '🏢 MeetingsService.createMeeting() - Retrieved meeting: ${meeting?.clientName}');

        // Sync to Google Calendar in background
        if (meeting != null) {
          _syncMeetingToGoogleCalendar(meeting, docId);
        }

        return meeting;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating meeting: $e');
      return null;
    }
  }

  static Future<List<Meeting>> getUpcomingMeetings() async {
    try {
      final now = DateTime.now();
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, now, now.add(const Duration(days: 365)),
          dateField: 'date');
      return documents.map<Meeting>((doc) => Meeting.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming meetings: $e');
      return [];
    }
  }

  /// Sync meeting to Google Calendar in background
  static Future<void> _syncMeetingToGoogleCalendar(
      Meeting meeting, String docId) async {
    try {
      debugPrint(
          '📅 Syncing meeting to Google Calendar: ${meeting.clientName}');

      // Convert Meeting to Event model for Google Calendar
      final event = Event(
        type: EventType.meeting,
        clientName: meeting.clientName,
        date: DateTime.parse(meeting.date),
        startTime: meeting.time,
        endTime: meeting.endTime,
        location: meeting.location,
        notes: meeting.notes,
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
        debugPrint('✅ Meeting synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync meeting to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing meeting to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync meeting update to Google Calendar in background
  static Future<void> _syncMeetingUpdateToGoogleCalendar(
      Meeting meeting, String docId) async {
    try {
      debugPrint(
          '📅 Syncing meeting update to Google Calendar: ${meeting.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      debugPrint(
          '📅 Retrieved document for sync check: ${doc != null ? "found" : "not found"}');

      if (doc == null) {
        debugPrint('❌ Meeting document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;
      debugPrint('📅 Google Calendar event ID: $googleCalendarEventId');

      // Check if meeting was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - creating new event instead');

        // Create a new Google Calendar event for this meeting
        debugPrint('📅 Creating new Google Calendar event for meeting...');
        _syncMeetingToGoogleCalendar(meeting, docId);
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert Meeting to Event model for Google Calendar
      final event = _meetingToEvent(meeting);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Meeting update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync meeting update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing meeting update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync meeting deletion to Google Calendar in background with event ID
  static Future<void> _syncMeetingDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint('📅 Syncing meeting deletion to Google Calendar: $clientName');

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
            '✅ Meeting deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync meeting deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing meeting deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert Meeting to Event model for Google Calendar
  static Event _meetingToEvent(Meeting meeting) {
    return Event(
      type: EventType.meeting,
      clientName: meeting.clientName,
      date: DateTime.parse(meeting.date),
      startTime: meeting.time,
      endTime: meeting.endTime,
      location: meeting.location,
      notes: meeting.notes,
    );
  }
}
