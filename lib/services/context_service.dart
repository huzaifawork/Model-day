import 'package:flutter/foundation.dart';
import '../services/jobs_service.dart';
import '../services/events_service.dart';
import '../services/ai_jobs_service.dart';
import '../services/user_service.dart';
import '../services/firebase_service_template.dart';
import '../services/agencies_service.dart';
import '../services/agents_service.dart';
import '../services/meetings_service.dart';
import '../services/on_stay_service.dart';
import '../services/shootings_service.dart';
import '../models/job.dart';
import '../models/event.dart';
import 'package:intl/intl.dart';

class ContextService {
  static final DateFormat _displayDateFormat = DateFormat('EEEE, MMMM d, yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  /// Build comprehensive user context for OpenAI (similar to React version)
  static Future<String> buildUserContext() async {
    try {
      debugPrint('🤖 ContextService.buildUserContext() - Building comprehensive user context...');

      final currentUserId = FirebaseServiceTemplate.currentUserId;
      if (currentUserId == null) {
        return 'User not authenticated. Please log in to access your modeling data.';
      }

      // Gather ALL user data in parallel (like React version)
      final futures = await Future.wait([
        _getUserProfile(currentUserId),
        _getAllJobs(),
        _getAllEvents(),
        _getAiJobs(),
        _getAgencies(),
        _getAgents(),
        _getMeetings(),
        _getOnStays(),
        _getShootings(),
      ]);

      final userProfile = futures[0];
      final jobs = futures[1];
      final events = futures[2];
      final aiJobs = futures[3];
      final agencies = futures[4];
      final agents = futures[5];
      final meetings = futures[6];
      final onStays = futures[7];
      final shootings = futures[8];

      // Calculate statistics (like React version)
      final statistics = await _calculateStatistics();
      final calendarSummary = await _getCalendarSummary();

      // Build comprehensive context in JSON-like format (similar to React)
      final context = '''
You are an AI assistant for a modeling professional using Model Day. You have access to ONLY their data and can help analyze it and provide insights.

CURRENT USER DATA CONTEXT:
$userProfile

JOBS DATA:
$jobs

EVENTS DATA:
$events

AI JOBS DATA:
$aiJobs

AGENCIES DATA:
$agencies

AGENTS DATA:
$agents

MEETINGS DATA:
$meetings

ON STAYS DATA:
$onStays

SHOOTINGS DATA:
$shootings

STATISTICS:
$statistics

UPCOMING CALENDAR (Next 10 Events):
$calendarSummary

Current Date: ${_displayDateFormat.format(DateTime.now())}
Current Time: ${_timeFormat.format(DateTime.now())}

Provide helpful, professional responses based on the actual data. Consider:
1. Financial insights: Total earnings, booking rates, job trends
2. Calendar management: Upcoming events, schedule conflicts, busy periods
3. Career development: Patterns in castings, successful job types, agent relationships
4. Network analysis: Industry contacts, agency relationships
5. Activity trends: Monthly or seasonal patterns in bookings and events

If calculating totals or analyzing trends, show actual numbers. If asked about something not in the data, let them know politely. Maintain a friendly, professional tone.
''';

      debugPrint('🤖 ContextService.buildUserContext() - Comprehensive context built successfully');
      return context;
    } catch (e) {
      debugPrint('❌ ContextService.buildUserContext() - Error: $e');
      return 'Error gathering user data. Please try again.';
    }
  }



  /// Get AI jobs
  static Future<String> _getAiJobs() async {
    try {
      final aiJobs = await AiJobsService.list();
      
      if (aiJobs.isEmpty) {
        return 'AI JOBS: No AI jobs found.';
      }

      final buffer = StringBuffer('AI JOBS:\n');
      for (final job in aiJobs.take(5)) { // Limit to 5 most recent
        final dateStr = job.date != null ? _displayDateFormat.format(job.date!) : 'Date TBD';
        final rate = job.rate != null ? '${job.rate} ${job.currency}' : 'Rate TBD';
        
        buffer.writeln('- $dateStr: ${job.clientName} (${job.type ?? 'AI Job'})');
        buffer.writeln('  Rate: $rate | Status: ${job.status} | Payment: ${job.paymentStatus}');
        if (job.location?.isNotEmpty == true) {
          buffer.writeln('  Location: ${job.location}');
        }
        buffer.writeln();
      }
      
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting AI jobs: $e');
      return 'AI JOBS: Error loading AI jobs data.';
    }
  }

  /// Get user profile information
  static Future<String> _getUserProfile(String userId) async {
    try {
      final user = await UserService.getUserById(userId);
      
      if (user == null) {
        return 'USER PROFILE: Profile not found.';
      }

      final buffer = StringBuffer('USER PROFILE:\n');
      buffer.writeln('- Name: ${user.name ?? 'Not specified'}');
      buffer.writeln('- Email: ${user.email}');
      if (user.phone?.isNotEmpty == true) {
        buffer.writeln('- Phone: ${user.phone}');
      }
      if (user.displayName?.isNotEmpty == true) {
        buffer.writeln('- Display Name: ${user.displayName}');
      }
      buffer.writeln();
      
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      return 'USER PROFILE: Error loading profile data.';
    }
  }

  /// Get all jobs with comprehensive data
  static Future<String> _getAllJobs() async {
    try {
      final jobs = await JobsService.list();

      if (jobs.isEmpty) {
        return 'JOBS: No jobs found.';
      }

      final buffer = StringBuffer('JOBS (${jobs.length} total):\n');

      // Calculate total earnings
      double totalEarnings = 0;
      int upcomingJobs = 0;
      int completedJobs = 0;

      for (final job in jobs) {
        totalEarnings += job.rate;

        try {
          if (job.date.isNotEmpty) {
            final jobDate = DateTime.parse(job.date);
            if (jobDate.isAfter(DateTime.now())) {
              upcomingJobs++;
            } else {
              completedJobs++;
            }
          }
        } catch (e) {
          // Skip invalid dates
        }

        String dateStr = 'Date TBD';
        try {
          if (job.date.isNotEmpty) {
            final jobDate = DateTime.parse(job.date);
            dateStr = _displayDateFormat.format(jobDate);
          }
        } catch (e) {
          dateStr = job.date;
        }

        buffer.writeln('- $dateStr: ${job.clientName} (${job.type})');
        buffer.writeln('  Rate: ${job.rate} ${job.currency ?? 'USD'} | Status: ${job.status} | Payment: ${job.paymentStatus}');
        buffer.writeln('  Location: ${job.location}');
        if (job.notes?.isNotEmpty == true) {
          buffer.writeln('  Notes: ${job.notes}');
        }
        buffer.writeln();
      }

      buffer.writeln('SUMMARY:');
      buffer.writeln('- Total Earnings: $totalEarnings USD');
      buffer.writeln('- Upcoming Jobs: $upcomingJobs');
      buffer.writeln('- Completed Jobs: $completedJobs');

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting all jobs: $e');
      return 'JOBS: Error loading jobs data.';
    }
  }

  /// Get all events with comprehensive data
  static Future<String> _getAllEvents() async {
    try {
      final eventsService = EventsService();
      final events = await eventsService.getEvents();

      if (events.isEmpty) {
        return 'EVENTS: No events found.';
      }

      final buffer = StringBuffer('EVENTS (${events.length} total):\n');

      for (final event in events.take(20)) { // Limit to 20 most recent
        final eventDate = event.date;
        final dateStr = eventDate != null ? _displayDateFormat.format(eventDate) : 'Date TBD';
        final timeStr = event.startTime ?? 'Time TBD';
        final location = event.location ?? 'Location TBD';

        buffer.writeln('- $dateStr at $timeStr: ${event.type.toString().split('.').last.toUpperCase()}');
        buffer.writeln('  Client: ${event.clientName ?? 'Unknown Client'}');
        buffer.writeln('  Location: $location');
        if (event.dayRate != null) {
          buffer.writeln('  Day Rate: ${event.dayRate} ${event.currency}');
        }
        if (event.notes?.isNotEmpty == true) {
          buffer.writeln('  Notes: ${event.notes}');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting all events: $e');
      return 'EVENTS: Error loading events data.';
    }
  }

  /// Get agencies data
  static Future<String> _getAgencies() async {
    try {
      final agencies = await AgenciesService.list();

      if (agencies.isEmpty) {
        return 'AGENCIES: No agencies found.';
      }

      final buffer = StringBuffer('AGENCIES (${agencies.length} total):\n');
      for (final agency in agencies) {
        buffer.writeln('- ${agency.name}');
        if (agency.city?.isNotEmpty == true) {
          buffer.writeln('  Location: ${agency.city}, ${agency.country ?? ''}');
        }
        if (agency.commissionRate > 0) {
          buffer.writeln('  Commission Rate: ${agency.commissionRate}%');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting agencies: $e');
      return 'AGENCIES: Error loading agencies data.';
    }
  }

  /// Get agents data
  static Future<String> _getAgents() async {
    try {
      final agentsService = AgentsService();
      final agents = await agentsService.getAgents();

      if (agents.isEmpty) {
        return 'AGENTS: No agents found.';
      }

      final buffer = StringBuffer('AGENTS (${agents.length} total):\n');
      for (final agent in agents) {
        buffer.writeln('- ${agent.name}');
        if (agent.email?.isNotEmpty == true) {
          buffer.writeln('  Email: ${agent.email}');
        }
        if (agent.phone?.isNotEmpty == true) {
          buffer.writeln('  Phone: ${agent.phone}');
        }
        if (agent.city?.isNotEmpty == true) {
          buffer.writeln('  Location: ${agent.city}, ${agent.country ?? ''}');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting agents: $e');
      return 'AGENTS: Error loading agents data.';
    }
  }

  /// Get meetings data
  static Future<String> _getMeetings() async {
    try {
      final meetings = await MeetingsService.list();

      if (meetings.isEmpty) {
        return 'MEETINGS: No meetings found.';
      }

      final buffer = StringBuffer('MEETINGS (${meetings.length} total):\n');
      for (final meeting in meetings.take(10)) {
        buffer.writeln('- ${meeting.date}: ${meeting.clientName}');
        if (meeting.time?.isNotEmpty == true) {
          buffer.writeln('  Time: ${meeting.time}');
        }
        if (meeting.location?.isNotEmpty == true) {
          buffer.writeln('  Location: ${meeting.location}');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting meetings: $e');
      return 'MEETINGS: Error loading meetings data.';
    }
  }

  /// Get on stays data
  static Future<String> _getOnStays() async {
    try {
      final onStays = await OnStayService.list();

      if (onStays.isEmpty) {
        return 'ON STAYS: No stays found.';
      }

      final buffer = StringBuffer('ON STAYS (${onStays.length} total):\n');
      for (final stay in onStays.take(10)) {
        buffer.writeln('- ${stay.locationName}');
        if (stay.checkInDate != null) {
          buffer.writeln('  Check-in: ${_displayDateFormat.format(stay.checkInDate!)}');
        }
        if (stay.checkOutDate != null) {
          buffer.writeln('  Check-out: ${_displayDateFormat.format(stay.checkOutDate!)}');
        }
        buffer.writeln('  Cost: ${stay.cost} ${stay.currency}');
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting on stays: $e');
      return 'ON STAYS: Error loading stays data.';
    }
  }

  /// Get shootings data
  static Future<String> _getShootings() async {
    try {
      final shootings = await ShootingsService.list();

      if (shootings.isEmpty) {
        return 'SHOOTINGS: No shootings found.';
      }

      final buffer = StringBuffer('SHOOTINGS (${shootings.length} total):\n');
      for (final shooting in shootings.take(10)) {
        String dateStr = 'Date TBD';
        try {
          if (shooting.date.isNotEmpty) {
            final shootingDate = DateTime.parse(shooting.date);
            dateStr = _displayDateFormat.format(shootingDate);
          }
        } catch (e) {
          dateStr = shooting.date;
        }

        buffer.writeln('- $dateStr: ${shooting.clientName}');
        if (shooting.location?.isNotEmpty == true) {
          buffer.writeln('  Location: ${shooting.location}');
        }
        if (shooting.rate != null) {
          buffer.writeln('  Rate: ${shooting.rate} ${shooting.currency}');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting shootings: $e');
      return 'SHOOTINGS: Error loading shootings data.';
    }
  }

  /// Calculate comprehensive statistics (like React version)
  static Future<String> _calculateStatistics() async {
    try {
      final jobs = await JobsService.list();
      final eventsService = EventsService();
      final events = await eventsService.getEvents();

      // Calculate financial statistics
      double totalIncome = 0;
      int upcomingJobs = 0;
      int completedJobs = 0;

      for (final job in jobs) {
        totalIncome += job.rate;

        try {
          if (job.date.isNotEmpty) {
            final jobDate = DateTime.parse(job.date);
            if (jobDate.isAfter(DateTime.now())) {
              upcomingJobs++;
            } else {
              completedJobs++;
            }
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      // Calculate events by month for trends
      final eventsByMonth = <String, int>{};
      final allEvents = [...jobs, ...events];

      for (final event in allEvents) {
        String? dateStr;
        if (event is Job && event.date.isNotEmpty) {
          dateStr = event.date;
        } else if (event is Event && event.date != null) {
          dateStr = event.date!.toIso8601String();
        }

        if (dateStr != null) {
          try {
            final date = DateTime.parse(dateStr);
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            eventsByMonth[monthKey] = (eventsByMonth[monthKey] ?? 0) + 1;
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      final buffer = StringBuffer('STATISTICS:\n');
      buffer.writeln('- Total Income: \$${totalIncome.toStringAsFixed(2)} USD');
      buffer.writeln('- Total Jobs: ${jobs.length}');
      buffer.writeln('- Upcoming Jobs: $upcomingJobs');
      buffer.writeln('- Completed Jobs: $completedJobs');
      buffer.writeln('- Total Events: ${events.length}');

      if (eventsByMonth.isNotEmpty) {
        buffer.writeln('- Activity by Month:');
        final sortedMonths = eventsByMonth.keys.toList()..sort();
        for (final month in sortedMonths.take(6)) { // Last 6 months
          buffer.writeln('  $month: ${eventsByMonth[month]} events');
        }
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error calculating statistics: $e');
      return 'STATISTICS: Error calculating statistics.';
    }
  }

  /// Get calendar summary with upcoming events (like React version)
  static Future<String> _getCalendarSummary() async {
    try {
      final jobs = await JobsService.list();
      final eventsService = EventsService();
      final events = await eventsService.getEvents();
      final meetings = await MeetingsService.list();

      final upcomingEvents = <Map<String, dynamic>>[];
      final now = DateTime.now();

      // Add jobs
      for (final job in jobs) {
        try {
          if (job.date.isNotEmpty) {
            final jobDate = DateTime.parse(job.date);
            if (jobDate.isAfter(now)) {
              upcomingEvents.add({
                'type': 'job',
                'title': job.clientName,
                'date': jobDate,
                'time': job.time ?? '',
                'location': job.location,
              });
            }
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      // Add events
      for (final event in events) {
        if (event.date != null && event.date!.isAfter(now)) {
          upcomingEvents.add({
            'type': event.type.toString().split('.').last,
            'title': event.clientName ?? 'Event',
            'date': event.date!,
            'time': event.startTime ?? '',
            'location': event.location ?? '',
          });
        }
      }

      // Add meetings
      for (final meeting in meetings) {
        try {
          if (meeting.date.isNotEmpty) {
            final meetingDate = DateTime.parse(meeting.date);
            if (meetingDate.isAfter(now)) {
              upcomingEvents.add({
                'type': 'meeting',
                'title': meeting.clientName,
                'date': meetingDate,
                'time': meeting.time ?? '',
                'location': meeting.location ?? '',
              });
            }
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      // Sort by date and take top 10
      upcomingEvents.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      final topEvents = upcomingEvents.take(10).toList();

      if (topEvents.isEmpty) {
        return 'UPCOMING CALENDAR: No upcoming events scheduled.';
      }

      final buffer = StringBuffer('UPCOMING CALENDAR (Next ${topEvents.length} Events):\n');
      for (final event in topEvents) {
        final date = event['date'] as DateTime;
        final dateStr = _displayDateFormat.format(date);
        final timeStr = event['time'] as String;
        final location = event['location'] as String;

        buffer.writeln('- $dateStr${timeStr.isNotEmpty ? ' at $timeStr' : ''}: ${event['type'].toString().toUpperCase()} - ${event['title']}');
        if (location.isNotEmpty) {
          buffer.writeln('  Location: $location');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error getting calendar summary: $e');
      return 'UPCOMING CALENDAR: Error loading calendar data.';
    }
  }
}
