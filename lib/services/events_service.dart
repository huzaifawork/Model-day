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
        debugPrint('✅ Event synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync event to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing event to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync event update to Google Calendar in background
  static Future<void> _syncEventUpdateToGoogleCalendar(
      Event event, String docId) async {
    try {
      debugPrint(
          '📅 Syncing event update to Google Calendar: ${event.clientName}');
      debugPrint('🔍 Event Google Calendar ID: ${event.googleCalendarEventId}');
      debugPrint('🔍 Event synced status: ${event.syncedToGoogleCalendar}');

      // Check if event was previously synced to Google Calendar
      if (event.googleCalendarEventId == null ||
          event.googleCalendarEventId!.isEmpty) {
        debugPrint('❌ No Google Calendar event ID found in event object');

        // Try to find Google Calendar event ID by searching for events with matching title
        debugPrint('🔍 Searching for Google Calendar event by title...');
        final googleCalendarEventId =
            await _findGoogleCalendarEventByTitle(event);

        if (googleCalendarEventId != null) {
          debugPrint(
              '✅ Found Google Calendar event ID: $googleCalendarEventId');

          // Update Firestore with the found Google Calendar event ID
          await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
            'google_calendar_event_id': googleCalendarEventId,
            'synced_to_google_calendar': true,
            'last_sync_date': DateTime.now().toIso8601String(),
          });

          // Now proceed with the update using the found event ID
          final success =
              await GoogleCalendarService.updateEventInGoogleCalendar(
                  googleCalendarEventId, event);

          if (success) {
            debugPrint(
                '✅ Event update synced to Google Calendar: $googleCalendarEventId');
          } else {
            debugPrint('❌ Failed to sync event update to Google Calendar');
          }
          return;
        } else {
          debugPrint(
              '❌ Could not find Google Calendar event - skipping update sync');
          debugPrint('🔍 Event data: ${event.toJson()}');
          return;
        }
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
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Event update synced to Google Calendar: ${event.googleCalendarEventId}');
      } else {
        debugPrint('❌ Failed to sync event update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing event update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync event deletion to Google Calendar in background
  static Future<void> _syncEventDeleteToGoogleCalendar(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint('📅 Syncing event deletion to Google Calendar: $clientName');

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
            '✅ Event deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync event deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing event deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Find Google Calendar event by searching for events with matching title
  static Future<String?> _findGoogleCalendarEventByTitle(Event event) async {
    try {
      debugPrint(
          '🔍 Searching for Google Calendar event with title: ${event.title}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - cannot search for events');
        return null;
      }

      // Search for events with matching title
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
