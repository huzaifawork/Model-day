import 'package:flutter/foundation.dart';
import '../models/polaroid.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class PolaroidsService {
  static const String _collectionName = 'polaroids';

  static Future<List<Polaroid>> list() async {
    try {
      debugPrint(
          '📸 PolaroidsService.list() - Fetching documents from $_collectionName');
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '📸 PolaroidsService.list() - Found ${documents.length} documents');

      final polaroids = documents.map<Polaroid>((doc) {
        debugPrint(
            '📸 PolaroidsService.list() - Processing document: ${doc['id']}');
        debugPrint('📸 PolaroidsService.list() - Document data: $doc');
        return Polaroid.fromJson(doc);
      }).toList();

      debugPrint(
          '📸 PolaroidsService.list() - Returning ${polaroids.length} polaroids');
      return polaroids;
    } catch (e) {
      debugPrint('📸 Error fetching polaroids: $e');
      return [];
    }
  }

  static Future<Polaroid?> create(Map<String, dynamic> polaroidData) async {
    try {
      debugPrint(
          '📸 PolaroidsService.create() - Creating polaroid with data: $polaroidData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, polaroidData);
      debugPrint(
          '📸 PolaroidsService.create() - Created document with ID: $docId');

      if (docId != null) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        debugPrint('📸 PolaroidsService.create() - Retrieved document: $doc');
        if (doc != null) {
          final polaroid = Polaroid.fromJson(doc);
          debugPrint(
              '📸 PolaroidsService.create() - Created polaroid: ${polaroid.clientName}');

          // Sync to Google Calendar in background
          _syncPolaroidToGoogleCalendar(polaroid, docId);

          return polaroid;
        }
      }
      debugPrint('📸 PolaroidsService.create() - Failed to create polaroid');
      return null;
    } catch (e) {
      debugPrint('📸 Error creating polaroid: $e');
      return null;
    }
  }

  static Future<Polaroid?> update(
      String id, Map<String, dynamic> polaroidData) async {
    try {
      debugPrint('📅 PolaroidsService.update() - Updating polaroid $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, polaroidData);
      if (success) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, id);
        if (doc != null) {
          final updatedPolaroid = Polaroid.fromJson(doc);

          // Sync update to Google Calendar if the polaroid was previously synced
          _syncPolaroidUpdateToGoogleCalendar(updatedPolaroid, id);

          return updatedPolaroid;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error updating polaroid: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 PolaroidsService.delete() - Deleting polaroid $id');

      // Get the existing polaroid AND document data to check for Google Calendar sync before deletion
      final existingPolaroid = await getPolaroidById(id);
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

      // Sync deletion to Google Calendar if the polaroid was previously synced
      if (success &&
          existingPolaroid != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        final eventForTitle = _polaroidToEvent(existingPolaroid);
        _syncPolaroidDeleteToGoogleCalendarWithEventId(googleCalendarEventId,
            eventForTitle.clientName ?? 'Polaroid Session');
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting polaroid: $e');
      return false;
    }
  }

  static Future<Polaroid?> getPolaroidById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Polaroid.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching polaroid: $e');
      return null;
    }
  }

  static Future<Polaroid?> updatePolaroid(
      String id, Map<String, dynamic> polaroidData) async {
    try {
      debugPrint(
          '📅 PolaroidsService.updatePolaroid() - Updating polaroid $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, polaroidData);
      if (success) {
        final updatedPolaroid = await getPolaroidById(id);

        // Sync update to Google Calendar if the polaroid was previously synced
        if (updatedPolaroid != null) {
          _syncPolaroidUpdateToGoogleCalendar(updatedPolaroid, id);
        }

        return updatedPolaroid;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating polaroid: $e');
      return null;
    }
  }

  static Future<Polaroid?> createPolaroid(
      Map<String, dynamic> polaroidData) async {
    try {
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, polaroidData);
      if (docId != null) {
        final polaroid = await getPolaroidById(docId);

        // Sync to Google Calendar in background
        if (polaroid != null) {
          _syncPolaroidToGoogleCalendar(polaroid, docId);
        }

        return polaroid;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating polaroid: $e');
      return null;
    }
  }

  static Future<List<Polaroid>> getPolaroids() async {
    return await list();
  }

  /// Sync polaroid to Google Calendar in background
  static Future<void> _syncPolaroidToGoogleCalendar(
      Polaroid polaroid, String docId) async {
    try {
      // Get a meaningful title for logging
      final eventForTitle = _polaroidToEvent(polaroid);
      debugPrint(
          '📅 Syncing polaroid to Google Calendar: ${eventForTitle.clientName}');

      // Validate that we have a valid date
      if (polaroid.date.isEmpty) {
        debugPrint('❌ No date provided for polaroid - skipping sync');
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Convert Polaroid to Event model for Google Calendar
      final event = _polaroidToEvent(polaroid);

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
        debugPrint('✅ Polaroid synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync polaroid to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing polaroid to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync polaroid update to Google Calendar in background
  static Future<void> _syncPolaroidUpdateToGoogleCalendar(
      Polaroid polaroid, String docId) async {
    try {
      // Get a meaningful title for logging
      final eventForTitle = _polaroidToEvent(polaroid);
      debugPrint(
          '📅 Syncing polaroid update to Google Calendar: ${eventForTitle.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ Polaroid document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if polaroid was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - creating new event instead');

        // Create a new Google Calendar event for this polaroid
        _syncPolaroidToGoogleCalendar(polaroid, docId);
        return;
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert Polaroid to Event model for Google Calendar
      final event = _polaroidToEvent(polaroid);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Polaroid update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync polaroid update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing polaroid update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync polaroid deletion to Google Calendar in background with event ID
  static Future<void> _syncPolaroidDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint(
          '📅 Syncing polaroid deletion to Google Calendar: $clientName');

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
            '✅ Polaroid deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync polaroid deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing polaroid deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert Polaroid to Event model for Google Calendar
  static Event _polaroidToEvent(Polaroid polaroid) {
    // Create a meaningful title for the event
    String eventTitle = 'Polaroid Session';

    if (polaroid.clientName.isNotEmpty) {
      eventTitle = polaroid.clientName;
    } else if (polaroid.location != null && polaroid.location!.isNotEmpty) {
      eventTitle = 'Polaroid Session - ${polaroid.location}';
    } else {
      // Use date as part of title if available
      try {
        final date = DateTime.parse(polaroid.date);
        final formattedDate = '${date.month}/${date.day}/${date.year}';
        eventTitle = 'Polaroid Session - $formattedDate';
      } catch (e) {
        eventTitle = 'Polaroid Session';
      }
    }

    return Event(
      type: EventType.polaroids,
      clientName: eventTitle,
      date: DateTime.parse(polaroid.date),
      startTime: polaroid.time,
      endTime: polaroid.endTime,
      location: polaroid.location,
      notes: polaroid.notes,
    );
  }
}
