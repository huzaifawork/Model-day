import 'package:flutter/foundation.dart';
import '../models/test.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class TestsService {
  static const String _collectionName = 'tests';

  static Future<List<Test>> list() async {
    try {
      debugPrint(
          '🧪 TestsService.list() - Fetching documents from $_collectionName');
      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🧪 TestsService.list() - Found ${documents.length} documents');

      final tests = documents.map<Test>((doc) {
        debugPrint(
            '🧪 TestsService.list() - Processing document: ${doc['id']}');
        debugPrint('🧪 TestsService.list() - Document data: $doc');
        return Test.fromJson(doc);
      }).toList();

      debugPrint('🧪 TestsService.list() - Returning ${tests.length} tests');
      return tests;
    } catch (e) {
      debugPrint('🧪 Error fetching tests: $e');
      return [];
    }
  }

  static Future<Test?> create(Map<String, dynamic> testData) async {
    try {
      debugPrint(
          '🧪 TestsService.create() - Creating test with data: $testData');
      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, testData);
      debugPrint('🧪 TestsService.create() - Created document with ID: $docId');

      if (docId != null) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        debugPrint('🧪 TestsService.create() - Retrieved document: $doc');
        if (doc != null) {
          final test = Test.fromJson(doc);
          debugPrint('🧪 TestsService.create() - Created test: ${test.title}');

          // Sync to Google Calendar in background
          _syncTestToGoogleCalendar(test, docId);

          return test;
        }
      }
      debugPrint('🧪 TestsService.create() - Failed to create test');
      return null;
    } catch (e) {
      debugPrint('🧪 Error creating test: $e');
      return null;
    }
  }

  static Future<Test?> update(String id, Map<String, dynamic> testData) async {
    try {
      debugPrint('📅 TestsService.update() - Updating test $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, testData);
      if (success) {
        final doc =
            await FirebaseServiceTemplate.getDocument(_collectionName, id);
        if (doc != null) {
          final updatedTest = Test.fromJson(doc);

          // Sync update to Google Calendar if the test was previously synced
          _syncTestUpdateToGoogleCalendar(updatedTest, id);

          return updatedTest;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error updating test: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint('📅 TestsService.delete() - Deleting test $id');

      // Get the existing test AND document data to check for Google Calendar sync before deletion
      final existingTest = await get(id);
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

      // Sync deletion to Google Calendar if the test was previously synced
      if (success &&
          existingTest != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncTestDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingTest.title);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting test: $e');
      return false;
    }
  }

  // Compatibility method
  static Future<Test?> get(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return Test.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching test: $e');
      return null;
    }
  }

  /// Sync test to Google Calendar in background
  static Future<void> _syncTestToGoogleCalendar(Test test, String docId) async {
    try {
      debugPrint('📅 Syncing test to Google Calendar: ${test.title}');

      // Convert Test to Event model for Google Calendar
      final event = Event(
        type: EventType.test,
        clientName: test.title,
        date: test.date,
        location: test.location,
        notes: test.description,
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
        debugPrint('✅ Test synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync test to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing test to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync test update to Google Calendar in background
  static Future<void> _syncTestUpdateToGoogleCalendar(
      Test test, String docId) async {
    try {
      debugPrint('📅 Syncing test update to Google Calendar: ${test.title}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ Test document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if test was previously synced to Google Calendar
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

      // Convert Test to Event model for Google Calendar
      final event = _testToEvent(test);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Test update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync test update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing test update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync test deletion to Google Calendar in background with event ID
  static Future<void> _syncTestDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String title) async {
    try {
      debugPrint('📅 Syncing test deletion to Google Calendar: $title');

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
            '✅ Test deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync test deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing test deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert Test to Event model for Google Calendar
  static Event _testToEvent(Test test) {
    return Event(
      type: EventType.test,
      clientName: test.title,
      date: test.date,
      startTime: null, // Test model doesn't have time fields
      endTime: null, // Test model doesn't have time fields
      location: test.location,
      notes: test.description,
    );
  }
}
