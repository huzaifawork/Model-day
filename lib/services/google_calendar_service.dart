import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/event.dart';
import 'oauth_config_service.dart';

class GoogleCalendarService {
  static calendar.CalendarApi? _calendarApi;
  static bool _isInitialized = false;
  static GoogleSignIn? _googleSignIn;

  /// Initialize Google Calendar API with authentication
  static Future<bool> initialize() async {
    try {
      debugPrint(
          '🗓️ GoogleCalendarService.initialize() - Starting initialization...');

      // Return early if already initialized to prevent re-authentication
      if (_isInitialized && _calendarApi != null) {
        debugPrint('✅ GoogleCalendarService already initialized, skipping...');
        return true;
      }

      // Reuse existing Google Sign-In instance from OAuthConfigService
      // This prevents additional authentication popups
      _googleSignIn = OAuthConfigService.getGoogleSignInInstance();

      // Try silent sign-in first to avoid popup with timeout
      debugPrint('🔐 Attempting silent sign-in...');
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn!.signInSilently().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏰ Silent sign-in timed out after 10 seconds');
            return null;
          },
        );
        debugPrint('🔐 Silent sign-in result: ${account?.email ?? 'null'}');
      } catch (e) {
        debugPrint('❌ Silent sign-in error: $e');
        account = null;
      }

      if (account == null) {
        debugPrint('🔐 Silent sign-in failed, checking current user...');
        account = _googleSignIn!.currentUser;
        debugPrint('🔐 Current user: ${account?.email ?? 'null'}');
      }

      // If still no account, check if we can request additional scopes without full sign-in
      if (account == null) {
        debugPrint('🔐 No existing Google account, attempting sign in...');
        try {
          // Try to request additional scopes for existing user with longer timeout
          debugPrint('🔐 Attempting sign-in with 30 second timeout...');
          account = await _googleSignIn!.signIn().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⏰ Sign-in timed out after 30 seconds');
              return null;
            },
          );
          debugPrint('🔐 Sign-in completed: ${account?.email ?? 'null'}');
        } catch (e) {
          debugPrint('🔐 Sign-in failed: $e');
          // If sign-in fails, the user might have cancelled
          return false;
        }
      }

      if (account == null) {
        debugPrint('❌ Google Sign-In failed or cancelled');
        return false;
      }

      debugPrint('✅ Google Sign-In successful: ${account.email}');

      // Get authenticated HTTP client with timeout
      debugPrint('🔐 Getting authenticated HTTP client...');
      final httpClient = await _googleSignIn!.authenticatedClient().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint(
              '⏰ Authenticated client request timed out after 20 seconds');
          return null;
        },
      );
      if (httpClient == null) {
        debugPrint('❌ Failed to get authenticated HTTP client');
        return false;
      }

      // Initialize Calendar API
      _calendarApi = calendar.CalendarApi(httpClient);
      _isInitialized = true;

      debugPrint('✅ Google Calendar API initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ GoogleCalendarService.initialize() error: $e');
      return false;
    }
  }

  /// Create an event in Google Calendar
  static Future<String?> createEventInGoogleCalendar(Event event) async {
    try {
      debugPrint('📅 Creating Google Calendar event: ${event.title}');

      // Ensure API is initialized
      if (!await initialize()) {
        debugPrint('❌ Failed to initialize Google Calendar API');
        return null;
      }

      // Debug event details
      debugPrint('🔍 Event details:');
      debugPrint('  - Date: ${event.date}');
      debugPrint('  - Start Time: ${event.startTime}');
      debugPrint('  - End Time: ${event.endTime}');
      debugPrint('  - Start DateTime: ${event.startDateTime}');
      debugPrint('  - End DateTime: ${event.endDateTime}');

      // Create Google Calendar event
      final calendarEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..location = event.location;

      // Set event timing
      if (event.startDateTime != null && event.endDateTime != null) {
        // Validate that end time is after start time
        if (event.endDateTime!.isBefore(event.startDateTime!) ||
            event.endDateTime!.isAtSameMomentAs(event.startDateTime!)) {
          debugPrint('❌ Invalid time range: end time must be after start time');
          debugPrint('  - Start: ${event.startDateTime}');
          debugPrint('  - End: ${event.endDateTime}');

          // Create a 1-hour event as fallback
          final adjustedEndTime =
              event.startDateTime!.add(const Duration(hours: 1));
          debugPrint('🔧 Adjusting end time to: $adjustedEndTime');

          calendarEvent.start = calendar.EventDateTime()
            ..dateTime = event.startDateTime!.toUtc()
            ..timeZone = 'UTC';

          calendarEvent.end = calendar.EventDateTime()
            ..dateTime = adjustedEndTime.toUtc()
            ..timeZone = 'UTC';
        } else {
          calendarEvent.start = calendar.EventDateTime()
            ..dateTime = event.startDateTime!.toUtc()
            ..timeZone = 'UTC';

          calendarEvent.end = calendar.EventDateTime()
            ..dateTime = event.endDateTime!.toUtc()
            ..timeZone = 'UTC';
        }
      } else if (event.date != null) {
        // All-day event
        debugPrint('📅 Creating all-day event for date: ${event.date}');
        final date = event.date!;
        calendarEvent.start = calendar.EventDateTime()
          ..dateTime = DateTime(date.year, date.month, date.day).toUtc();

        final endDate = date.add(const Duration(days: 1));
        calendarEvent.end = calendar.EventDateTime()
          ..dateTime =
              DateTime(endDate.year, endDate.month, endDate.day).toUtc();
      } else {
        debugPrint('❌ No valid date/time information provided for event');
        return null;
      }

      // Insert event into primary calendar
      final createdEvent =
          await _calendarApi!.events.insert(calendarEvent, 'primary');

      debugPrint('✅ Google Calendar event created: ${createdEvent.id}');
      return createdEvent.id;
    } catch (e) {
      debugPrint('❌ Error creating Google Calendar event: $e');
      return null;
    }
  }

  /// Update an existing event in Google Calendar
  static Future<bool> updateEventInGoogleCalendar(
      String eventId, Event event) async {
    try {
      debugPrint('📅 Updating Google Calendar event: $eventId');

      // Ensure API is initialized
      if (!await initialize()) {
        debugPrint('❌ Failed to initialize Google Calendar API');
        return false;
      }

      // Create updated Google Calendar event
      final calendarEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..location = event.location;

      // Set event timing
      if (event.startDateTime != null && event.endDateTime != null) {
        // Validate that end time is after start time
        if (event.endDateTime!.isBefore(event.startDateTime!) ||
            event.endDateTime!.isAtSameMomentAs(event.startDateTime!)) {
          debugPrint('❌ Invalid time range: end time must be after start time');
          debugPrint('  - Start: ${event.startDateTime}');
          debugPrint('  - End: ${event.endDateTime}');

          // Create a 1-hour event as fallback
          final adjustedEndTime =
              event.startDateTime!.add(const Duration(hours: 1));
          debugPrint('🔧 Adjusting end time to: $adjustedEndTime');

          calendarEvent.start = calendar.EventDateTime()
            ..dateTime = event.startDateTime!.toUtc()
            ..timeZone = 'UTC';

          calendarEvent.end = calendar.EventDateTime()
            ..dateTime = adjustedEndTime.toUtc()
            ..timeZone = 'UTC';
        } else {
          calendarEvent.start = calendar.EventDateTime()
            ..dateTime = event.startDateTime!.toUtc()
            ..timeZone = 'UTC';

          calendarEvent.end = calendar.EventDateTime()
            ..dateTime = event.endDateTime!.toUtc()
            ..timeZone = 'UTC';
        }
      } else if (event.date != null) {
        // All-day event
        debugPrint('📅 Updating all-day event for date: ${event.date}');
        final date = event.date!;
        calendarEvent.start = calendar.EventDateTime()
          ..dateTime = DateTime(date.year, date.month, date.day).toUtc();

        final endDate = date.add(const Duration(days: 1));
        calendarEvent.end = calendar.EventDateTime()
          ..dateTime =
              DateTime(endDate.year, endDate.month, endDate.day).toUtc();
      } else {
        debugPrint('❌ No valid date/time information provided for event');
        return false;
      }

      // Update event in primary calendar
      await _calendarApi!.events.update(calendarEvent, 'primary', eventId);

      debugPrint('✅ Google Calendar event updated: $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating Google Calendar event: $e');
      return false;
    }
  }

  /// Delete an event from Google Calendar
  static Future<bool> deleteEventInGoogleCalendar(String eventId) async {
    try {
      debugPrint('📅 Deleting Google Calendar event: $eventId');

      // Ensure API is initialized
      if (!await initialize()) {
        debugPrint('❌ Failed to initialize Google Calendar API');
        return false;
      }

      // Delete event from primary calendar
      await _calendarApi!.events.delete('primary', eventId);

      debugPrint('✅ Google Calendar event deleted: $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting Google Calendar event: $e');
      return false;
    }
  }

  /// Find Google Calendar event by title and date
  static Future<String?> findEventByTitle(String title, DateTime? date) async {
    try {
      debugPrint('🔍 Searching for Google Calendar event with title: $title');

      // Ensure API is initialized
      if (!await initialize()) {
        debugPrint('❌ Failed to initialize Google Calendar API');
        return null;
      }

      // Set up search parameters
      DateTime searchStart;
      DateTime searchEnd;

      if (date != null) {
        // Search within a day range around the event date
        searchStart = DateTime(date.year, date.month, date.day);
        searchEnd = searchStart.add(const Duration(days: 1));
      } else {
        // Search within the last 30 days if no date provided
        searchStart = DateTime.now().subtract(const Duration(days: 30));
        searchEnd = DateTime.now().add(const Duration(days: 30));
      }

      debugPrint('🔍 Searching from $searchStart to $searchEnd');

      // First, try to get all events in the date range and search manually
      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: searchStart.toUtc(),
        timeMax: searchEnd.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      debugPrint('🔍 Found ${events.items?.length ?? 0} events in date range');

      if (events.items != null && events.items!.isNotEmpty) {
        // Log all events for debugging
        for (final event in events.items!) {
          debugPrint('📅 Event: "${event.summary}" (ID: ${event.id})');
        }

        // Normalize the search title for comparison
        final normalizedSearchTitle = _normalizeTitle(title);
        debugPrint('🔍 Normalized search title: "$normalizedSearchTitle"');

        // Look for exact title match
        for (final event in events.items!) {
          final normalizedEventTitle = _normalizeTitle(event.summary ?? '');
          debugPrint('🔍 Comparing with: "$normalizedEventTitle"');

          if (normalizedEventTitle == normalizedSearchTitle) {
            debugPrint('✅ Found exact match: ${event.id}');
            return event.id;
          }
        }

        // Look for partial matches (contains client name)
        final clientName =
            title.contains(' - ') ? title.split(' - ').last : title;
        final normalizedClientName = _normalizeTitle(clientName);
        debugPrint('🔍 Searching for client name: "$normalizedClientName"');

        for (final event in events.items!) {
          final normalizedEventTitle = _normalizeTitle(event.summary ?? '');
          if (normalizedEventTitle.contains(normalizedClientName)) {
            debugPrint('✅ Found partial match: ${event.id} (${event.summary})');
            return event.id;
          }
        }

        debugPrint('❌ No matching events found');
      } else {
        debugPrint('❌ No events found in date range');
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error searching for Google Calendar event: $e');
      return null;
    }
  }

  /// Normalize title for comparison (remove extra spaces, convert to lowercase)
  static String _normalizeTitle(String title) {
    return title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  /// Reset initialization state (useful for testing or re-authentication)
  static void resetInitialization() {
    _isInitialized = false;
    _calendarApi = null;
    _googleSignIn = null;
    debugPrint('🔄 GoogleCalendarService reset');
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Test Google Calendar access
  static Future<bool> testCalendarAccess() async {
    try {
      debugPrint('🧪 Testing Google Calendar access...');

      final initResult = await initialize();
      debugPrint('🧪 Calendar initialization result: $initResult');

      if (!initResult) {
        debugPrint('❌ Calendar initialization failed');
        return false;
      }

      // Try to list calendars to test access with timeout
      debugPrint('🧪 Attempting to list calendars...');
      final calendars = await _calendarApi!.calendarList.list().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Calendar list request timed out');
          throw Exception('Calendar list request timed out');
        },
      );
      debugPrint(
          '✅ Calendar access test successful - found ${calendars.items?.length ?? 0} calendars');
      return true;
    } catch (e) {
      debugPrint('❌ Calendar access test failed: $e');
      return false;
    }
  }
}
