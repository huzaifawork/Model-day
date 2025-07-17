import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/option.dart';
import '../models/event.dart';
import 'google_calendar_service.dart';

class OptionsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  static CollectionReference get _optionsCollection {
    return _firestore.collection('users').doc(_userId).collection('options');
  }

  /// Create a new option
  static Future<String> create(Map<String, dynamic> optionData) async {
    try {
      final docRef = await _optionsCollection.add({
        ...optionData,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Sync to Google Calendar in background
      final option = await getById(docRef.id);
      if (option != null) {
        _syncOptionToGoogleCalendar(option, docRef.id);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create option: $e');
    }
  }

  /// Get all options for the current user
  static Future<List<Option>> list() async {
    try {
      final querySnapshot = await _optionsCollection
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert Firestore Timestamps to DateTime strings
        if (data['created_at'] is Timestamp) {
          data['created_at'] =
              (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_at'] is Timestamp) {
          data['updated_at'] =
              (data['updated_at'] as Timestamp).toDate().toIso8601String();
        }

        return Option.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch options: $e');
    }
  }

  /// Get a specific option by ID
  static Future<Option?> getById(String optionId) async {
    try {
      final doc = await _optionsCollection.doc(optionId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      // Convert Firestore Timestamps to DateTime strings
      if (data['created_at'] is Timestamp) {
        data['created_at'] =
            (data['created_at'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updated_at'] is Timestamp) {
        data['updated_at'] =
            (data['updated_at'] as Timestamp).toDate().toIso8601String();
      }

      return Option.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch option: $e');
    }
  }

  /// Update an existing option
  static Future<void> update(
      String optionId, Map<String, dynamic> optionData) async {
    try {
      // Get the existing option to check for Google Calendar sync
      final existingOption = await getById(optionId);

      await _optionsCollection.doc(optionId).update({
        ...optionData,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Sync update to Google Calendar if the option was previously synced
      if (existingOption != null) {
        final updatedOption = await getById(optionId);
        if (updatedOption != null) {
          _syncOptionUpdateToGoogleCalendar(updatedOption, optionId);
        }
      }
    } catch (e) {
      throw Exception('Failed to update option: $e');
    }
  }

  /// Delete an option
  static Future<void> delete(String optionId) async {
    try {
      // Get the existing option and document data to check for Google Calendar sync before deletion
      final existingOption = await getById(optionId);
      final doc = await _optionsCollection.doc(optionId).get();

      String? googleCalendarEventId;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        googleCalendarEventId = data['google_calendar_event_id'] as String?;
      }

      // Delete from Firestore
      await _optionsCollection.doc(optionId).delete();

      // Sync deletion to Google Calendar if the option was previously synced
      if (existingOption != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        _syncOptionDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingOption.clientName);
      }
    } catch (e) {
      throw Exception('Failed to delete option: $e');
    }
  }

  /// Get options by status
  static Future<List<Option>> getByStatus(String status) async {
    try {
      final querySnapshot = await _optionsCollection
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert Firestore Timestamps to DateTime strings
        if (data['created_at'] is Timestamp) {
          data['created_at'] =
              (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_at'] is Timestamp) {
          data['updated_at'] =
              (data['updated_at'] as Timestamp).toDate().toIso8601String();
        }

        return Option.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch options by status: $e');
    }
  }

  /// Get options by date range
  static Future<List<Option>> getByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final querySnapshot = await _optionsCollection
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert Firestore Timestamps to DateTime strings
        if (data['created_at'] is Timestamp) {
          data['created_at'] =
              (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_at'] is Timestamp) {
          data['updated_at'] =
              (data['updated_at'] as Timestamp).toDate().toIso8601String();
        }

        return Option.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch options by date range: $e');
    }
  }

  /// Search options by client name or type
  static Future<List<Option>> search(String query) async {
    try {
      final allOptions = await list();

      return allOptions.where((option) {
        final clientName = option.clientName.toLowerCase();
        final type = option.type.toLowerCase();
        final searchQuery = query.toLowerCase();

        return clientName.contains(searchQuery) || type.contains(searchQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search options: $e');
    }
  }

  /// Sync option to Google Calendar in background
  static Future<void> _syncOptionToGoogleCalendar(
      Option option, String docId) async {
    try {
      debugPrint('📅 Syncing option to Google Calendar: ${option.clientName}');

      // Convert Option to Event model for Google Calendar
      final event = Event(
        type: EventType.option,
        clientName: option.clientName,
        date: DateTime.parse(option.date),
        startTime: option.time,
        endTime: option.endTime,
        location: option.location,
        notes: option.notes,
      );

      // Create event in Google Calendar
      final calendarEventId =
          await GoogleCalendarService.createEventInGoogleCalendar(event);

      if (calendarEventId != null) {
        // Update Firestore with sync status
        await _optionsCollection.doc(docId).update({
          'google_calendar_event_id': calendarEventId,
          'synced_to_google_calendar': true,
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Option synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync option to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing option to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync option update to Google Calendar in background
  static Future<void> _syncOptionUpdateToGoogleCalendar(
      Option option, String docId) async {
    try {
      debugPrint(
          '📅 Syncing option update to Google Calendar: ${option.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc = await _optionsCollection.doc(docId).get();
      if (!doc.exists) {
        debugPrint('❌ Option document not found - skipping update sync');
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final googleCalendarEventId = data['google_calendar_event_id'] as String?;

      // Check if option was previously synced to Google Calendar
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

      // Convert Option to Event model for Google Calendar
      final event = Event(
        type: EventType.option,
        clientName: option.clientName,
        date: DateTime.parse(option.date),
        startTime: option.time,
        endTime: option.endTime,
        location: option.location,
        notes: option.notes,
      );

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await _optionsCollection.doc(docId).update({
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Option update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync option update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing option update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync option deletion to Google Calendar in background with event ID
  static Future<void> _syncOptionDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint('📅 Syncing option deletion to Google Calendar: $clientName');

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
            '✅ Option deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync option deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing option deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }
}
