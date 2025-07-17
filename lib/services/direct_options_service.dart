import 'package:flutter/foundation.dart';
import '../models/direct_options.dart';
import '../models/event.dart';
import 'firebase_service_template.dart';
import 'google_calendar_service.dart';

class DirectOptionsService {
  static const String _collectionName = 'direct_options';

  static Future<List<DirectOptions>> list() async {
    try {
      debugPrint(
          '🔍 DirectOptionsService.list() - Fetching from collection: $_collectionName');
      debugPrint(
          '🔍 DirectOptionsService.list() - User authenticated: ${FirebaseServiceTemplate.isAuthenticated}');
      debugPrint(
          '🔍 DirectOptionsService.list() - Current user ID: ${FirebaseServiceTemplate.currentUserId}');

      final documents =
          await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint(
          '🔍 DirectOptionsService.list() - Retrieved ${documents.length} documents');

      final options = documents.map<DirectOptions>((doc) {
        debugPrint(
            '🔍 DirectOptionsService.list() - Processing document: ${doc['id']}');
        return DirectOptions.fromJson(doc);
      }).toList();

      debugPrint(
          '✅ DirectOptionsService.list() - Successfully converted ${options.length} direct options');
      return options;
    } catch (e) {
      debugPrint(
          '❌ DirectOptionsService.list() - Error fetching direct options: $e');
      return [];
    }
  }

  static Future<DirectOptions?> getById(String id) async {
    try {
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, id);
      if (doc != null) {
        return DirectOptions.fromJson(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching direct option: $e');
      return null;
    }
  }

  static Future<DirectOptions?> create(Map<String, dynamic> optionData) async {
    try {
      debugPrint(
          '🔍 DirectOptionsService.create() - Creating direct option with data: $optionData');
      debugPrint(
          '🔍 DirectOptionsService.create() - User authenticated: ${FirebaseServiceTemplate.isAuthenticated}');

      final docId = await FirebaseServiceTemplate.createDocument(
          _collectionName, optionData);
      debugPrint(
          '🔍 DirectOptionsService.create() - Created document with ID: $docId');

      if (docId != null) {
        final option = await getById(docId);
        debugPrint(
            '✅ DirectOptionsService.create() - Successfully created direct option: ${option?.id}');

        // Sync to Google Calendar in background
        if (option != null) {
          debugPrint('🔄 Starting Google Calendar sync for direct option...');
          _syncDirectOptionToGoogleCalendar(option, docId);
        } else {
          debugPrint('❌ Cannot sync to Google Calendar - option is null');
        }

        return option;
      }
      debugPrint('❌ DirectOptionsService.create() - Failed to create document');
      return null;
    } catch (e) {
      debugPrint(
          '❌ DirectOptionsService.create() - Error creating direct option: $e');
      return null;
    }
  }

  static Future<DirectOptions?> update(
      String id, Map<String, dynamic> optionData) async {
    try {
      debugPrint(
          '📅 DirectOptionsService.update() - Updating direct option $id');

      final success = await FirebaseServiceTemplate.updateDocument(
          _collectionName, id, optionData);
      if (success) {
        final updatedOption = await getById(id);

        // Sync update to Google Calendar if the option was previously synced
        if (updatedOption != null) {
          _syncDirectOptionUpdateToGoogleCalendar(updatedOption, id);
        }

        return updatedOption;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating direct option: $e');
      return null;
    }
  }

  static Future<bool> delete(String id) async {
    try {
      debugPrint(
          '📅 DirectOptionsService.delete() - Deleting direct option $id');

      // Get the existing option AND document data to check for Google Calendar sync before deletion
      final existingOption = await getById(id);
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

      // Sync deletion to Google Calendar if the option was previously synced
      if (success &&
          existingOption != null &&
          googleCalendarEventId != null &&
          googleCalendarEventId.isNotEmpty) {
        debugPrint('🔄 Starting Google Calendar delete sync...');
        _syncDirectOptionDeleteToGoogleCalendarWithEventId(
            googleCalendarEventId, existingOption.clientName);
      } else {
        debugPrint(
            '❌ Skipping Google Calendar delete sync - no event ID found');
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting direct option: $e');
      return false;
    }
  }

  static Future<List<DirectOptions>> getByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final documents = await FirebaseServiceTemplate.getDocumentsByDateRange(
          _collectionName, startDate, endDate,
          dateField: 'date');
      return documents
          .map<DirectOptions>((doc) => DirectOptions.fromJson(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching direct options by date range: $e');
      return [];
    }
  }

  static Future<List<DirectOptions>> search(String query) async {
    try {
      final documents = await FirebaseServiceTemplate.searchDocuments(
          _collectionName, 'title', query);
      return documents
          .map<DirectOptions>((doc) => DirectOptions.fromJson(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching direct options: $e');
      return [];
    }
  }

  /// Sync direct option to Google Calendar in background
  static Future<void> _syncDirectOptionToGoogleCalendar(
      DirectOptions option, String docId) async {
    try {
      debugPrint(
          '📅 Syncing direct option to Google Calendar: ${option.clientName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping sync');
        return;
      }

      // Validate that we have a valid date
      if (option.date == null) {
        debugPrint('❌ No date provided for direct option - skipping sync');
        return;
      }

      // Validate time range if both start and end times are provided
      if (option.time != null && option.endTime != null) {
        try {
          final startParts = option.time!.split(':');
          final endParts = option.endTime!.split(':');
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
              type: EventType.directOption,
              clientName: option.clientName,
              date: option.date,
              startTime: option.time,
              endTime: adjustedEndTime,
              location: option.location,
              notes: option.notes,
              dayRate: option.rate,
              currency: option.currency,
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
                  '✅ Direct option synced to Google Calendar with adjusted time: $calendarEventId');
            } else {
              debugPrint('❌ Failed to sync direct option to Google Calendar');
            }
            return;
          }
        } catch (e) {
          debugPrint('❌ Error parsing time values: $e');
          // Continue with original times, let Google Calendar handle it
        }
      }

      // Convert DirectOptions to Event model for Google Calendar
      final event = Event(
        type: EventType.directOption,
        clientName: option.clientName,
        date: option.date,
        startTime: option.time,
        endTime: option.endTime,
        location: option.location,
        notes: option.notes,
        dayRate: option.rate,
        currency: option.currency,
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
            '✅ Direct option synced to Google Calendar: $calendarEventId');
      } else {
        debugPrint('❌ Failed to sync direct option to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing direct option to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync direct option update to Google Calendar in background
  static Future<void> _syncDirectOptionUpdateToGoogleCalendar(
      DirectOptions option, String docId) async {
    try {
      debugPrint(
          '📅 Syncing direct option update to Google Calendar: ${option.clientName}');

      // Get the document to check for Google Calendar sync fields
      final doc =
          await FirebaseServiceTemplate.getDocument(_collectionName, docId);
      if (doc == null) {
        debugPrint('❌ Direct option document not found - skipping update sync');
        return;
      }

      final googleCalendarEventId = doc['google_calendar_event_id'] as String?;

      // Check if option was previously synced to Google Calendar
      if (googleCalendarEventId == null || googleCalendarEventId.isEmpty) {
        debugPrint(
            '❌ No Google Calendar event ID found - skipping update sync');

        // Try to find Google Calendar event ID by searching for events with matching title
        debugPrint('🔍 Searching for Google Calendar event by title...');
        final foundEventId = await _findGoogleCalendarEventByTitle(option);

        if (foundEventId != null) {
          debugPrint('✅ Found Google Calendar event ID: $foundEventId');

          // Update Firestore with the found Google Calendar event ID
          await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
            'google_calendar_event_id': foundEventId,
            'synced_to_google_calendar': true,
            'last_sync_date': DateTime.now().toIso8601String(),
          });

          // Now proceed with the update using the found event ID
          final success =
              await GoogleCalendarService.updateEventInGoogleCalendar(
                  foundEventId, _directOptionToEvent(option));

          if (success) {
            debugPrint(
                '✅ Direct option update synced to Google Calendar: $foundEventId');
          } else {
            debugPrint(
                '❌ Failed to sync direct option update to Google Calendar');
          }
          return;
        } else {
          debugPrint(
              '❌ Could not find Google Calendar event - skipping update sync');
          return;
        }
      }

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - skipping update sync');
        return;
      }

      // Convert DirectOptions to Event model for Google Calendar
      final event = _directOptionToEvent(option);

      // Update event in Google Calendar
      final success = await GoogleCalendarService.updateEventInGoogleCalendar(
          googleCalendarEventId, event);

      if (success) {
        // Update Firestore with sync status
        await FirebaseServiceTemplate.updateDocument(_collectionName, docId, {
          'last_sync_date': DateTime.now().toIso8601String(),
        });
        debugPrint(
            '✅ Direct option update synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint('❌ Failed to sync direct option update to Google Calendar');
      }
    } catch (e) {
      debugPrint('❌ Error syncing direct option update to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Sync direct option deletion to Google Calendar in background with event ID
  static Future<void> _syncDirectOptionDeleteToGoogleCalendarWithEventId(
      String googleCalendarEventId, String clientName) async {
    try {
      debugPrint(
          '📅 Syncing direct option deletion to Google Calendar: $clientName');

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
            '✅ Direct option deletion synced to Google Calendar: $googleCalendarEventId');
      } else {
        debugPrint(
            '❌ Failed to sync direct option deletion to Google Calendar');
      }
    } catch (e) {
      debugPrint(
          '❌ Error syncing direct option deletion to Google Calendar: $e');
      // Don't throw error - sync failure shouldn't break the app
    }
  }

  /// Convert DirectOptions to Event model for Google Calendar
  static Event _directOptionToEvent(DirectOptions option) {
    return Event(
      type: EventType.directOption,
      clientName: option.clientName,
      date: option.date,
      startTime: option.time,
      endTime: option.endTime,
      location: option.location,
      notes: option.notes,
      dayRate: option.rate,
      currency: option.currency,
    );
  }

  /// Find Google Calendar event by searching for events with matching title
  static Future<String?> _findGoogleCalendarEventByTitle(
      DirectOptions option) async {
    try {
      debugPrint(
          '🔍 Searching for Google Calendar event with title: Direct Option - ${option.clientName}');

      // Test calendar access first
      final hasAccess = await GoogleCalendarService.testCalendarAccess();
      if (!hasAccess) {
        debugPrint('❌ No Google Calendar access - cannot search for events');
        return null;
      }

      // Search for events with matching title
      final event = _directOptionToEvent(option);
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
