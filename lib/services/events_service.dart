import 'package:flutter/foundation.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class EventsService {
  static const String _collectionName = 'events';

  Future<List<Event>> getEvents() async {
    try {
      debugPrint('📅 EventsService.getEvents() - Fetching events...');
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '📅 EventsService.getEvents() - Found ${documents.length} documents');
      final events =
          documents.map<Event>((doc) => Event.fromJson(doc)).toList();
      debugPrint(
          '📅 EventsService.getEvents() - Parsed ${events.length} events');
      return events;
    } catch (e) {
      debugPrint('❌ Error fetching events: $e');
      return [];
    }
  }

  /// Get events with raw document data for filtering by email fields
  Future<List<Map<String, dynamic>>> getEventsWithRawData() async {
    try {
      debugPrint('📅 EventsService.getEventsWithRawData() - Fetching ALL events for approvals filtering...');
      // Important: Approvals need to see events where current user is either the model or the agent,
      // which may include events created by another user. So we must fetch all documents here.
      final documents = await FirebaseServiceTemplate.getDocuments(_collectionName);
      debugPrint(
          '📅 EventsService.getEventsWithRawData() - Found ${documents.length} total events');
      return documents;
    } catch (e) {
      debugPrint('❌ Error fetching events with raw data: $e');
      return [];
    }
  }

  Future<Event?> createEvent(Map<String, dynamic> eventData) async {
    try {
      debugPrint(
          '📅 EventsService.createEvent() - Creating event with data: $eventData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, eventData);
      debugPrint(
          '📅 EventsService.createEvent() - Created document with ID: $docId');
      if (docId != null) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        if (doc != null) {
          final event = Event.fromJson(doc);
          debugPrint(
              '📅 EventsService.createEvent() - Retrieved event: ${event.clientName}');

          // Sync to Google Calendar in background
          debugPrint('🔄 Starting Google Calendar sync for event...');
          _syncEventToGoogleCalendar(event, docId);

          return event;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating event: $e');
      return null;
    }
  }

  Future<Event?> updateEvent(String id, Map<String, dynamic> eventData) async {
    try {
      debugPrint(
          '📅 EventsService.updateEvent() - Updating event $id with data: $eventData');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, eventData);
      if (success) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, id);
        if (doc != null) {
          debugPrint(
              '📅 EventsService.updateEvent() - Retrieved document: $doc');
          debugPrint('🔍 Document Google Calendar fields:');
          debugPrint(
              '  - google_calendar_event_id: ${doc['google_calendar_event_id']}');
          debugPrint(
              '  - synced_to_google_calendar: ${doc['synced_to_google_calendar']}');
          debugPrint('  - last_sync_date: ${doc['last_sync_date']}');

          final updatedEvent = Event.fromJson(doc);
          debugPrint('🔍 Event object Google Calendar fields:');
          debugPrint(
              '  - googleCalendarEventId: ${updatedEvent.googleCalendarEventId}');
          debugPrint(
              '  - syncedToGoogleCalendar: ${updatedEvent.syncedToGoogleCalendar}');
          debugPrint('  - lastSyncDate: ${updatedEvent.lastSyncDate}');

          // Sync update to Google Calendar if the event was previously synced
          _syncEventUpdateToGoogleCalendar(updatedEvent, id);

          return updatedEvent;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      // Get the existing event to check for Google Calendar sync before deletion
      final existingEvent = await getEventById(id);

      // Delete from Firestore
      final success =
          await FirebaseServiceTemplate.deleteDocument(_collectionName, id);

      // Sync deletion to Google Calendar if the event was previously synced
      if (success &&
          existingEvent != null &&
          existingEvent.googleCalendarEventId != null &&
          existingEvent.googleCalendarEventId!.isNotEmpty) {
        _syncEventDeleteToGoogleCalendar(existingEvent.googleCalendarEventId!,
            existingEvent.clientName ?? 'Unknown');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  Future<Event?> getEventById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Event.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching event: $e');
      return null;
    }
  }

  /// Get events with pending status for approvals
  Future<List<Event>> getPendingEvents() async {
    try {
      debugPrint('📅 EventsService.getPendingEvents() - Fetching pending events...');
      final documents = await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint('📅 EventsService.getPendingEvents() - Found ${documents.length} total documents');
      
      final pendingEvents = documents
          .where((doc) => doc['status'] == 'pending')
          .map<Event>((doc) => Event.fromJson(doc))
          .toList();
      
      debugPrint('📅 EventsService.getPendingEvents() - Found ${pendingEvents.length} pending events');
      return pendingEvents;
    } catch (e) {
      debugPrint('❌ Error fetching pending events: $e');
      return [];
    }
  }

  /// Approve an event by updating its status
  Future<bool> approveEvent(String eventId) async {
    try {
      debugPrint('📅 EventsService.approveEvent() - Approving event: $eventId');
      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, eventId, {'status': 'approved'});
      debugPrint('📅 EventsService.approveEvent() - Success: $success');
      return success;
    } catch (e) {
      debugPrint('❌ Error approving event: $e');
      return false;
    }
  }

  /// Approve an event and sync to Google Calendar
  Future<bool> approveEventWithCalendarSync(String eventId) async {
    try {
      debugPrint('📅 EventsService.approveEventWithCalendarSync() - Approving event: $eventId');
      
      // First, get the event details
      final eventDoc = await FirebaseServiceTemplate.getDocument(_collectionName, eventId);
      if (eventDoc == null) {
        debugPrint('❌ Event document not found: $eventId');
        return false;
      }
      
      // Update event status to approved
      final statusUpdateSuccess = await FirebaseServiceTemplate.updateDocument(
          _collectionName, eventId, {'status': 'approved'});
      
      if (!statusUpdateSuccess) {
        debugPrint('❌ Failed to update event status to approved');
        return false;
      }
      
      // Convert document to Event object for calendar sync
      final event = Event.fromJson(eventDoc);
      
      // Sync to Google Calendar using the proper method
      await _syncEventToGoogleCalendar(event, eventId);
      
      debugPrint('✅ Event approved and synced to calendar: $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Error approving event with calendar sync: $e');
      return false;
    }
  }

  /// Reject an event by updating its status
  Future<bool> rejectEvent(String eventId) async {
    try {
      debugPrint('📅 EventsService.rejectEvent() - Rejecting event: $eventId');
      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, eventId, {'status': 'rejected'});
      debugPrint('📅 EventsService.rejectEvent() - Success: $success');
      return success;
    } catch (e) {
      debugPrint('❌ Error rejecting event: $e');
      return false;
    }
  }

  /// Sync event to Google Calendar in background
  static Future<void> _syncEventToGoogleCalendar(
      Event event, String docId) async {
    try {
      debugPrint('📅 Syncing event to Google Calendar: ${event.clientName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Create event in Google Calendar (event is already in the right format)
      final calendarEventId =
          await GoogleCalendarService.createEventInGoogleCalendar(event);

      if (calendarEventId != null) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'google_calendar_event_id': calendarEventId,
          'synced_to_google_calendar': true,
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Event synced to Google Calendar with ID: $calendarEventId');
      } else {
        debugPrint('❌ Failed to create event in Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing event to Google Calendar: $e');
    }
  }

  /// Sync update to Google Calendar
  static Future<void> _syncEventUpdateToGoogleCalendar(
      Event event, String docId) async {
    try {
      debugPrint('📅 Syncing event update to Google Calendar: ${event.clientName}');

      // Only attempt sync if event was previously synced
      if (event.googleCalendarEventId == null ||
          event.googleCalendarEventId!.isEmpty) {
        debugPrint('ℹ️ Event has no Google Calendar ID, skipping update sync');
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          event.googleCalendarEventId!, event);

      if (success) {
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'synced_to_google_calendar': true,
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Event update synced to Google Calendar');
      } else {
        debugPrint('❌ Failed to update event in Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing event update to Google Calendar: $e');
    }
  }

  /// Sync delete to Google Calendar
  static Future<void> _syncEventDeleteToGoogleCalendar(
      String eventId, String eventTitle) async {
    try {
      debugPrint('📅 Syncing event delete to Google Calendar: $eventTitle');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping delete sync');
        return;
      }

      final success =
          await GoogleCalendarService.deleteEventInGoogleCalendar(eventId);

      if (success) {
        debugPrint('✅ Event delete synced to Google Calendar');
      } else {
        debugPrint('❌ Failed to delete event in Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing event delete to Google Calendar: $e');
    }
  }
}
