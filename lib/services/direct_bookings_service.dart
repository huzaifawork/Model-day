import 'package:flutter/foundation.dart';
import '../models/direct_booking.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class DirectBookingsService {
  static const String _collectionName = 'direct_bookings';

  static Future<List<DirectBooking>> list() async {
    try {
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      final List<DirectBooking> bookings = [];

      for (final doc in documents) {
        try {
          final booking = DirectBooking.fromJson(doc);
          bookings.add(booking);
        } catch (e) {
          debugPrint('Error parsing individual direct booking document: $e');
          debugPrint('Document data: $doc');
          debugPrint('Document type: ${doc.runtimeType}');
          // Continue processing other documents
        }
      }

      return bookings;
    } catch (e) {
      debugPrint('Error fetching direct bookings: $e');
      return [];
    }
  }

  static Future<DirectBooking?> getById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        try {
          return DirectBooking.fromJson(doc);
        } catch (e) {
          debugPrint('Error parsing direct booking document with ID $id: $e');
          debugPrint('Document data: $doc');
          debugPrint('Document type: ${doc.runtimeType}');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching direct booking: $e');
      return null;
    }
  }

  static Future<DirectBooking?> create(Map<String, dynamic> bookingData) async {
    try {
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, bookingData);
      if (docId != null) {
        final booking = await getById(docId);

        // Sync to Google Calendar in background
        if (booking != null) {
          _syncDirectBookingToGoogleCalendar(booking, docId);
        }

        return booking;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating direct booking: $e');
      return null;
    }
  }

  static Future<DirectBooking?> update(
      String id, Map<String, dynamic> bookingData) async {
    try {
      debugPrint(
          '📅 DirectBookingsService.update() - Updating direct booking $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, bookingData);
      if (success) {
        final updatedBooking = await getById(id);

        // Sync update to Google Calendar if the booking was previously synced
        if (updatedBooking != null) {
          _syncDirectBookingUpdateToGoogleCalendar(updatedBooking, id);
        }

        return updatedBooking;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating direct booking: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint(
          '📅 DirectBookingsService.delete() - Deleting direct booking $id');

      // Get the existing booking AND document data to check for Google Calendar sync before deletion
      final existingBooking = await getById(id);
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

      // Sync deletion to Google Calendar if the booking was previously synced
      if (success &&
          existingBooking != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncDirectBookingDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingBooking.clientName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting direct booking: $e');
      return false;
    }
  }

  static Future<List<DirectBooking>> getByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, startDate, endDate,
          dateField: 'date');
      return documents
          .map<DirectBooking>((doc) => DirectBooking.fromJson(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching direct bookings by date range: $e');
      return [];
    }
  }

  static Future<List<DirectBooking>> search(String query) async {
    try {
      final documents = await FirebaseServiceTemplate.searchDocuments(
          _collectionName, 'title', query);
      return documents
          .map<DirectBooking>((doc) => DirectBooking.fromJson(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching direct bookings: $e');
      return [];
    }
  }

  /// Sync direct booking to Google Calendar in background
  static Future<void> _syncDirectBookingToGoogleCalendar(
      DirectBooking booking, String docId) async {
    try {
      debugPrint(
          '📅 Syncing direct booking to Google Calendar: ${booking.clientName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Validate that we have a valid date
      if (booking.date == null) {
        debugPrint('❌ No date provided for direct booking - skipping sync');
        return;
      }

      // Validate time range if both start and end times are provided
      if (booking.time != null && booking.endTime != null) {
        try {
          final startParts = booking.time!.split(':');
          final endParts = booking.endTime!.split(':');
          final startMinutes =
              int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          final endMinutes =
              int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

          if (startMinutes >= endMinutes) {
            debugPrint(
                '❌ Invalid time range: start time must be before end time');
            // Set a default 1-hour duration if times are invalid
            final startHour = int.parse(startParts[0]);
            final startMinute = int.parse(startParts[1]);
            final endHour = startMinute >= 30 ? startHour + 1 : startHour;
            final endMinuteAdjusted =
                startMinute >= 30 ? startMinute - 30 : startMinute + 30;
            final adjustedEndTime =
                '${endHour.toString().padLeft(2, '0')}:${endMinuteAdjusted.toString().padLeft(2, '0')}';

            // Create event with adjusted end time
            final event = Event(
              type: EventType.directBooking,
              clientName: booking.clientName,
              date: booking.date,
              startTime: booking.time,
              endTime: adjustedEndTime,
              location: booking.location,
              notes: booking.notes,
              dayRate: booking.rate,
              currency: booking.currency,
            );

            // Create event in Google Calendar
            final calendarEventId =
                await GoogleCalendarService.createEventInGoogleCalendar(event);

            if (calendarEventId != null) {
              // Update Firestore with sync status
              await FirebaseServiceTemplate.updateDocument(
                  _collectionName, docId, {
                'google_calendar_event_id': calendarEventId,
                'synced_to_google_calendar': true,
                'last_sync_date': DateTime.now().toIso8601String(),
              });
              debugPrint(
                  '✅ Direct booking synced to Google Calendar with adjusted time: $calendarEventId');
            } else {
              debugPrint('❌ Failed to sync direct booking to Google Calendar');
            }
            return;
          }
        } catch (e) {
          debugPrint('❌ Error parsing time values: $e');
          // Continue with original times, let Google Calendar handle it
        }
      }

      // Convert DirectBooking to Event model for Google Calendar
      final event = Event(
        type: EventType.directBooking,
        clientName: booking.clientName,
        date: booking.date,
        startTime: booking.time,
        endTime: booking.endTime,
        location: booking.location,
        notes: booking.notes,
        dayRate: booking.rate,
        currency: booking.currency,
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
        debugPrint(
            '✅ Direct booking synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync direct booking to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing direct booking to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync direct booking update to Google Calendar in background
  static Future<void> _syncDirectBookingUpdateToGoogleCalendar(
      DirectBooking booking, String docId) async {
    try {
      debugPrint(
          '📅 Syncing direct booking update to Google Calendar: ${booking.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint(
            '❌ Direct booking document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if booking was previously synced to Google Calendar
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

      // Convert DirectBooking to Event model for Google Calendar
      final event = _directBookingToEvent(booking);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Direct booking update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync direct booking update to Google Calendar');
      }
    } catch (e) {
      debugPrint(
          '❌ Error syncing direct booking update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync direct booking deletion to Google Calendar in background with event ID
  static Future<void> _syncDirectBookingDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint(
          '📅 Syncing direct booking deletion to Google Calendar: $clientName');

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
            '✅ Direct booking deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint(
            '❌ Failed to sync direct booking deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint(
          '❌ Error syncing direct booking deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert DirectBooking to Event model for Google Calendar
  static Event _directBookingToEvent(DirectBooking booking) {
    return Event(
      type: EventType.directBooking,
      clientName: booking.clientName,
      date: booking.date,
      startTime: booking.time,
      endTime: booking.endTime,
      location: booking.location,
      notes: booking.notes,
      dayRate: booking.rate,
      currency: booking.currency,
    );
  }
}
