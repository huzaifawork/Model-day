import 'package:flutter/foundation.dart';
import '../models/shooting.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class ShootingsService {
  static const String _collectionName = 'shootings';

  static Future<List<Shooting>> list() async {
    try {
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      return documents.map<Shooting>((doc) => Shooting.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching shootings: $e');
      return [];
    }
  }

  static Future<Shooting?> create(Map<String, dynamic> shootingData) async {
    try {
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, shootingData);
      if (docId != null) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        if (doc != null) {
          final shooting = Shooting.fromJson(doc);

          // Sync to Google Calendar in background
          _syncShootingToGoogleCalendar(shooting, docId);

          return shooting;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error creating shooting: $e');
      return null;
    }
  }

  static Future<Shooting?> update(
      String id, Map<String, dynamic> shootingData) async {
    try {
      debugPrint('📅 ShootingsService.update() - Updating shooting $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, shootingData);
      if (success) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, id);
        if (doc != null) {
          final updatedShooting = Shooting.fromJson(doc);

          // Sync update to Google Calendar if the shooting was previously synced
          _syncShootingUpdateToGoogleCalendar(updatedShooting, id);

          return updatedShooting;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error updating shooting: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 ShootingsService.delete() - Deleting shooting $id');

      // Get the existing shooting AND document data to check for Google Calendar sync before deletion
      final existingShooting = await getShootingById(id);
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

      // Sync deletion to Google Calendar if the shooting was previously synced
      if (success &&
          existingShooting != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncShootingDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingShooting.clientName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting shooting: $e');
      return false;
    }
  }

  static Future<Shooting?> getShootingById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Shooting.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching shooting: $e');
      return null;
    }
  }

  static Future<Shooting?> updateShooting(
      String id, Map<String, dynamic> shootingData) async {
    try {
      debugPrint(
          '📅 ShootingsService.updateShooting() - Updating shooting $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, shootingData);
      if (success) {
        final updatedShooting = await getShootingById(id);

        // Sync update to Google Calendar if the shooting was previously synced
        if (updatedShooting != null) {
          _syncShootingUpdateToGoogleCalendar(updatedShooting, id);
        }

        return updatedShooting;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating shooting: $e');
      return null;
    }
  }

  static Future<Shooting?> createShooting(
      Map<String, dynamic> shootingData) async {
    try {
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, shootingData);
      if (docId != null) {
        final shooting = await getShootingById(docId);

        // Sync to Google Calendar in background
        if (shooting != null) {
          _syncShootingToGoogleCalendar(shooting, docId);
        }

        return shooting;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating shooting: $e');
      return null;
    }
  }

  static Future<List<Shooting>> getShootings() async {
    return await list();
  }

  /// Sync shooting to Google Calendar in background
  static Future<void> _syncShootingToGoogleCalendar(
      Shooting shooting, String docId) async {
    try {
      debugPrint(
          '📅 Syncing shooting to Google Calendar: ${shooting.clientName}');

      // Convert Shooting to Event model for Google Calendar
      final event = Event(
        type: EventType.other,
        clientName: shooting.clientName,
        date: DateTime.parse(shooting.date),
        startTime: shooting.time,
        endTime: shooting.endTime,
        location: shooting.location,
        notes: shooting.notes,
        dayRate: shooting.rate,
        currency: shooting.currency,
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
        debugPrint('✅ Shooting synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync shooting to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing shooting to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync shooting update to Google Calendar in background
  static Future<void> _syncShootingUpdateToGoogleCalendar(
      Shooting shooting, String docId) async {
    try {
      debugPrint(
          '📅 Syncing shooting update to Google Calendar: ${shooting.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ Shooting document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if shooting was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - creating new event instead');

        // Create a new Google Calendar event for this shooting
        _syncShootingToGoogleCalendar(shooting, docId);
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert Shooting to Event model for Google Calendar
      final event = _shootingToEvent(shooting);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Shooting update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync shooting update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing shooting update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync shooting deletion to Google Calendar in background with event ID
  static Future<void> _syncShootingDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint(
          '📅 Syncing shooting deletion to Google Calendar: $clientName');

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
            '✅ Shooting deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync shooting deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing shooting deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert Shooting to Event model for Google Calendar
  static Event _shootingToEvent(Shooting shooting) {
    return Event(
      type: EventType.other,
      clientName: shooting.clientName,
      date: DateTime.parse(shooting.date),
      startTime: shooting.time,
      endTime: shooting.endTime,
      location: shooting.location,
      notes: shooting.notes,
      dayRate: shooting.rate,
      currency: shooting.currency,
    );
  }
}
