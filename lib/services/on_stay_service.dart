import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/on_stay.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class OnStayService {
  static const String _collectionName = 'on_stay';

  static Future<List<OnStay>> list() async {
    try {
      debugPrint(
          '🏨 OnStayService.list() - Fetching documents from $_collectionName');
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🏨 OnStayService.list() - Found ${documents.length} documents');

      final stays = documents.map<OnStay>((doc) {
        debugPrint(
            '🏨 OnStayService.list() - Processing document: ${doc['id']}');
        debugPrint('🏨 OnStayService.list() - Document data: $doc');
        return OnStay.fromJson(doc);
      }).toList();

      debugPrint('🏨 OnStayService.list() - Returning ${stays.length} stays');
      return stays;
    } catch (e) {
      debugPrint('🏨 Error fetching on stay records: $e');
      return [];
    }
  }

  static Future<OnStay?> getById(String id) async {
    try {
      debugPrint('🏨 OnStayService.getById() - Fetching stay with ID: $id');
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        debugPrint(
            '🏨 OnStayService.getById() - Found stay: ${doc['title'] ?? doc['location_name']}');
        return OnStay.fromJson(doc);
      }
      debugPrint('🏨 OnStayService.getById() - Stay not found');
      return null;
    } catch (e) {
      debugPrint('🏨 Error fetching on stay by ID: $e');
      return null;
    }
  }

  static Future<OnStay?> create(Map<String, dynamic> onStayData) async {
    try {
      debugPrint(
          '🏨 OnStayService.create() - Creating stay with data: $onStayData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, onStayData);
      debugPrint(
          '🏨 OnStayService.create() - Created document with ID: $docId');

      if (docId != null) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        debugPrint('🏨 OnStayService.create() - Retrieved document: $doc');
        if (doc != null) {
          final stay = OnStay.fromJson(doc);
          debugPrint(
              '🏨 OnStayService.create() - Created stay: ${stay.locationName}');

          // Sync to Google Calendar in background
          _syncOnStayToGoogleCalendar(stay, docId);

          return stay;
        }
      }
      debugPrint('🏨 OnStayService.create() - Failed to create stay');
      return null;
    } catch (e) {
      debugPrint('🏨 Error creating on stay record: $e');
      return null;
    }
  }

  static Future<OnStay?> update(
      String id, Map<String, dynamic> onStayData) async {
    try {
      debugPrint('📅 OnStayService.update() - Updating on stay $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, onStayData);
      if (success) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, id);
        if (doc != null) {
          final updatedStay = OnStay.fromJson(doc);

          // Sync update to Google Calendar if the stay was previously synced
          _syncOnStayUpdateToGoogleCalendar(updatedStay, id);

          return updatedStay;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error updating on stay record: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 OnStayService.delete() - Deleting on stay $id');

      // Get the existing stay AND document data to check for Google Calendar sync before deletion
      final existingStay = await getById(id);
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

      // Sync deletion to Google Calendar if the stay was previously synced
      if (success &&
          existingStay != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncOnStayDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingStay.locationName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting on stay record: $e');
      return false;
    }
  }

  static Future<List<OnStay>> getUpcoming() async {
    try {
      final now = DateTime.now();
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, now, now.add(const Duration(days: 365)),
          dateField: 'start_date');
      return documents.map<OnStay>((doc) => OnStay.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming on stay records: $e');
      return [];
    }
  }

  static Future<List<OnStay>> getCurrent() async {
    try {
      final now = DateTime.now();
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, now.subtract(const Duration(days: 30)), now,
          dateField: 'start_date');
      return documents.map<OnStay>((doc) => OnStay.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching current on stay records: $e');
      return [];
    }
  }

  static Future<List<OnStay>> getPast() async {
    try {
      final now = DateTime.now();
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName,
          now.subtract(const Duration(days: 365)),
          now.subtract(const Duration(days: 1)),
          dateField: 'end_date');
      return documents.map<OnStay>((doc) => OnStay.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching past on stay records: $e');
      return [];
    }
  }

  /// Sync on stay to Google Calendar in background
  static Future<void> _syncOnStayToGoogleCalendar(
      OnStay stay, String docId) async {
    try {
      debugPrint('📅 Syncing on stay to Google Calendar: ${stay.locationName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Validate dates
      final checkInDate = stay.checkInDate ?? DateTime.now();
      final checkOutDate =
          stay.checkOutDate ?? checkInDate.add(const Duration(days: 1));

      // Convert OnStay to Event model for Google Calendar
      final event = Event(
        type: EventType.onStay,
        clientName: stay.locationName,
        date: checkInDate,
        endDate: checkOutDate,
        startTime: stay.checkInTime,
        endTime: stay.checkOutTime,
        location: stay.address ?? stay.locationName,
        notes: _buildOnStayDescription(stay),
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
        debugPrint('✅ On stay synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync on stay to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing on stay to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Build description for Google Calendar event
  static String _buildOnStayDescription(OnStay stay) {
    List<String> parts = [];

    parts.add('ON STAY DETAILS');
    parts.add('Location: ${stay.locationName}');

    if (stay.address != null && stay.address!.isNotEmpty) {
      parts.add('Address: ${stay.address}');
    }

    if (stay.contactName != null && stay.contactName!.isNotEmpty) {
      parts.add('Agency: ${stay.contactName}');
    }

    if (stay.checkInDate != null && stay.checkOutDate != null) {
      final checkIn = DateFormat('MMM d, yyyy').format(stay.checkInDate!);
      final checkOut = DateFormat('MMM d, yyyy').format(stay.checkOutDate!);
      parts.add('Duration: $checkIn - $checkOut');
    }

    if (stay.cost > 0) {
      parts.add('Cost: ${stay.currency} ${stay.cost}');
    }

    if (stay.notes != null && stay.notes!.isNotEmpty) {
      parts.add('Notes: ${stay.notes}');
    }

    return parts.join('\n\n');
  }

  /// Sync on stay update to Google Calendar in background
  static Future<void> _syncOnStayUpdateToGoogleCalendar(
      OnStay stay, String docId) async {
    try {
      debugPrint(
          '📅 Syncing on stay update to Google Calendar: ${stay.locationName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ On stay document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if stay was previously synced to Google Calendar
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

      // Convert OnStay to Event model for Google Calendar
      final event = _onStayToEvent(stay);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ On stay update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync on stay update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing on stay update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync on stay deletion to Google Calendar in background with event ID
  static Future<void> _syncOnStayDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String locationName) async {
    try {
      debugPrint(
          '📅 Syncing on stay deletion to Google Calendar: $locationName');

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
            '✅ On stay deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync on stay deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing on stay deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert OnStay to Event model for Google Calendar
  static Event _onStayToEvent(OnStay stay) {
    final checkInDate = stay.checkInDate ?? DateTime.now();
    final checkOutDate =
        stay.checkOutDate ?? checkInDate.add(const Duration(days: 1));

    return Event(
      type: EventType.onStay,
      clientName: stay.locationName,
      date: checkInDate,
      endDate: checkOutDate,
      startTime: stay.checkInTime,
      endTime: stay.checkOutTime,
      location: stay.address ?? stay.locationName,
      notes: _buildOnStayDescription(stay),
    );
  }
}
