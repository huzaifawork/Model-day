import 'package:flutter/foundation.dart';
import '../models/casting.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class CastingsService {
  static const String _collectionName = 'castings';

  static Future<List<Casting>> list() async {
    try {
      debugPrint(
          '🔍 CastingsService.list() - Fetching castings from collection: $_collectionName');
      debugPrint(
          '🔍 CastingsService.list() - User authenticated: ${FirebaseServiceTemplate.isAuthenticated}');
      debugPrint(
          '🔍 CastingsService.list() - Current user ID: ${FirebaseServiceTemplate.currentUserId}');

      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🔍 CastingsService.list() - Retrieved ${documents.length} documents');

      final castings = documents.map<Casting>((doc) {
        debugPrint(
            '🔍 CastingsService.list() - Processing document: ${doc['id']}');
        return Casting.fromJson(doc);
      }).toList();

      debugPrint(
          '🔍 CastingsService.list() - Returning ${castings.length} castings');
      return castings;
    } catch (e) {
      debugPrint('❌ Error fetching castings: $e');
      return [];
    }
  }

  static Future<Casting?> getById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Casting.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching casting: $e');
      return null;
    }
  }

  static Future<Casting?> create(Map<String, dynamic> castingData) async {
    try {
      debugPrint(
          '🔍 CastingsService.create() - Creating casting with data: $castingData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, castingData);
      debugPrint(
          '🔍 CastingsService.create() - Created document with ID: $docId');
      if (docId != null) {
        final casting = await getById(docId);
        debugPrint(
            '🔍 CastingsService.create() - Retrieved created casting: ${casting?.id}');

        // Sync to Google Calendar in background
        if (casting != null) {
          _syncCastingToGoogleCalendar(casting, docId);
        }

        return casting;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating casting: $e');
      return null;
    }
  }

  static Future<Casting?> update(
      String id, Map<String, dynamic> castingData) async {
    try {
      debugPrint('📅 CastingsService.update() - Updating casting $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, castingData);
      if (success) {
        final updatedCasting = await getById(id);

        // Sync update to Google Calendar if the casting was previously synced
        if (updatedCasting != null) {
          _syncCastingUpdateToGoogleCalendar(updatedCasting, id);
        }

        return updatedCasting;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating casting: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 CastingsService.delete() - Deleting casting $id');

      // Get the existing casting AND document data to check for Google Calendar sync before deletion
      final existingCasting = await getById(id);
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

      // Sync deletion to Google Calendar if the casting was previously synced
      if (success &&
          existingCasting != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncCastingDeleteToGoogleCalendarWithEventId(googleCalendarEventId,
            existingCasting.clientName ?? existingCasting.title);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting casting: $e');
      return false;
    }
  }

  // Compatibility method
  static Future<Casting?> get(String id) async {
    return await getById(id);
  }

  /// Sync casting to Google Calendar in background
  static Future<void> _syncCastingToGoogleCalendar(
      Casting casting, String docId) async {
    try {
      debugPrint('📅 Syncing casting to Google Calendar: ${casting.title}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Date is always available in casting model (required field)

      // Extract start and end times from description if available
      String? startTime;
      String? endTime;

      if (casting.description != null) {
        final lines = casting.description!.split('\n');
        for (String line in lines) {
          if (line.contains('Start Time:')) {
            startTime = line.split('Start Time:')[1].trim();
          } else if (line.contains('End Time:')) {
            endTime = line.split('End Time:')[1].trim();
          }
        }
      }

      // Validate time range if both start and end times are provided
      if (startTime != null && endTime != null) {
        try {
          // Parse times to validate they're in correct format
          final startParts =
              startTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
          final endParts = endTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');

          if (startParts.length >= 2 && endParts.length >= 2) {
            final startMinutes =
                int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
            final endMinutes =
                int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

            if (startMinutes >= endMinutes) {
              debugPrint(
                  '❌ Invalid time range: start time must be before end time');
              // Set a default 2-hour duration for castings
              final startHour = int.parse(startParts[0]);
              final startMinute = int.parse(startParts[1]);
              final endHour = startHour + 2;
              endTime =
                  '${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
              debugPrint('🔧 Adjusted end time to: $endTime');
            }
          }
        } catch (e) {
          debugPrint('❌ Error parsing time values: $e');
          // Continue with original times, let Google Calendar handle it
        }
      }

      // Convert Casting to Event model for Google Calendar
      final event = Event(
        type: EventType.casting,
        clientName: casting.title,
        date: casting.date,
        startTime: startTime,
        endTime: endTime,
        location: casting.location,
        notes: casting.description,
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
        debugPrint('✅ Casting synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync casting to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing casting to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync casting update to Google Calendar in background
  static Future<void> _syncCastingUpdateToGoogleCalendar(
      Casting casting, String docId) async {
    try {
      debugPrint(
          '📅 Syncing casting update to Google Calendar: ${casting.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ Casting document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if casting was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - skipping update sync');
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert Casting to Event model for Google Calendar
      final event = _castingToEvent(casting);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Casting update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync casting update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing casting update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync casting deletion to Google Calendar in background with event ID
  static Future<void> _syncCastingDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint('📅 Syncing casting deletion to Google Calendar: $clientName');

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
            '✅ Casting deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync casting deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing casting deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert Casting to Event model for Google Calendar
  static Event _castingToEvent(Casting casting) {
    return Event(
      type: EventType.casting,
      clientName: casting.title,
      date: casting.date,
      startTime: null, // Casting model doesn't have time fields
      endTime: null, // Casting model doesn't have time fields
      location: casting.location,
      notes: casting.description,
    );
  }
}
