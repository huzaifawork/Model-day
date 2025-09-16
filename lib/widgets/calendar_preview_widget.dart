import 'package:flutter/material.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'clickable_contact_info.dart';
import '../models/job.dart';
import '../models/casting.dart';
import '../models/test.dart';
import '../models/event.dart';
import '../models/ai_job.dart';
import '../models/agent.dart';
import '../services/jobs_service.dart';
import '../services/events_service.dart';
import '../services/auth_service.dart';
import '../services/on_stay_service.dart';
import '../services/meetings_service.dart';
import '../services/direct_bookings_service.dart';
import '../services/polaroids_service.dart';
import '../services/ai_jobs_service.dart';
import '../services/agents_service.dart';
import '../models/on_stay.dart';
import '../models/meeting.dart';
import '../models/option.dart';
import '../models/direct_booking.dart';
import '../models/direct_options.dart';
import '../models/polaroid.dart';

class CalendarPreviewWidget extends StatefulWidget {
  final bool isFullCalendar;

  const CalendarPreviewWidget({
    super.key,
    this.isFullCalendar = false,
  });

  @override
  State<CalendarPreviewWidget> createState() => _CalendarPreviewWidgetState();
}

class _CalendarPreviewWidgetState extends State<CalendarPreviewWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  String? _error;
  Map<DateTime, List<dynamic>> _events = {};
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAgents();
    if (widget.isFullCalendar) {
      _loadEvents();
    }
  }

  Future<void> _loadAgents() async {
    try {
      final agentsService = AgentsService();
      final agents = await agentsService.getAgents();
      if (mounted) {
        setState(() {
          _agentCache = {
            for (final agent in agents)
              if (agent.id != null) agent.id!: agent
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading agents: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all event types
      final jobs = await JobsService.list();
      final castings = await Casting.list();
      final tests = await Test.list();
      final onStays = await OnStayService.list();
      final meetings = await MeetingsService.list();
      // Load options from EventsService (same as options page)
      final allEvents = await EventsService().getEvents();
      final options = allEvents.where((event) => event.type == EventType.option).toList();
      final directBookings = await DirectBookingsService.list();
      // Load direct options from EventsService (same as direct options page)
      final allEventsForDirectOptions = await EventsService().getEvents();
      final directOptions = allEventsForDirectOptions.where((event) => event.type == EventType.directOption).toList();
      final polaroids = await PolaroidsService.list();
      final aiJobs = await AiJobsService.list();

      // Load general events from EventsService
      final generalEvents = await _getEventsForCalendarPreview();

      final events = <DateTime, List<dynamic>>{};

      // Group jobs by date (handle multi-day events)
      for (final job in jobs) {
        try {
          final startDate = DateTime.parse(job.date);
          final startDateKey =
              DateTime(startDate.year, startDate.month, startDate.day);

          // Check if it's a multi-day job
          if (job.isMultiDay &&
              job.endDate != null &&
              job.endDate!.isNotEmpty) {
            try {
              final endDate = DateTime.parse(job.endDate!);
              final endDateKey =
                  DateTime(endDate.year, endDate.month, endDate.day);

              // Add job to all dates in the range
              DateTime currentDate = startDateKey;
              while (currentDate.isBefore(endDateKey) ||
                  currentDate.isAtSameMomentAs(endDateKey)) {
                events[currentDate] = [...(events[currentDate] ?? []), job];
                currentDate = currentDate.add(const Duration(days: 1));
              }
            } catch (e) {
              debugPrint('Error parsing job end date: ${job.endDate} - $e');
              // Fallback to single day
              events[startDateKey] = [...(events[startDateKey] ?? []), job];
            }
          } else {
            // Single day job
            events[startDateKey] = [...(events[startDateKey] ?? []), job];
          }
        } catch (e) {
          debugPrint('Error parsing job date: ${job.date} - $e');
          continue;
        }
      }

      // Group castings by date
      for (final casting in castings) {
        try {
          final date = DateTime(
            casting.date.year,
            casting.date.month,
            casting.date.day,
          );
          events[date] = [...(events[date] ?? []), casting];
        } catch (e) {
          debugPrint('Error processing casting date: $e');
          continue;
        }
      }

      // Group tests by date
      for (final test in tests) {
        try {
          final date = DateTime(test.date.year, test.date.month, test.date.day);
          events[date] = [...(events[date] ?? []), test];
        } catch (e) {
          debugPrint('Error processing test date: $e');
          continue;
        }
      }

      // Group general events by date (handle multi-day events)
      for (final event in generalEvents) {
        try {
          if (event.date != null) {
            final startDate = DateTime(
              event.date!.year,
              event.date!.month,
              event.date!.day,
            );

            // Check if it has an end date for multi-day event
            if (event.endDate != null) {
              final endDate = DateTime(
                event.endDate!.year,
                event.endDate!.month,
                event.endDate!.day,
              );

              // Only treat as multi-day if end date is different from start date
              if (!endDate.isAtSameMomentAs(startDate)) {
                // Add event to all dates in the range
                DateTime currentDate = startDate;
                while (currentDate.isBefore(endDate) ||
                    currentDate.isAtSameMomentAs(endDate)) {
                  events[currentDate] = [...(events[currentDate] ?? []), event];
                  currentDate = currentDate.add(const Duration(days: 1));
                }
              } else {
                // Same day start and end
                events[startDate] = [...(events[startDate] ?? []), event];
              }
            } else {
              // Single day event
              events[startDate] = [...(events[startDate] ?? []), event];
            }
          }
        } catch (e) {
          debugPrint('Error processing general event date: $e');
          continue;
        }
      }

      // Group OnStay events by date (handle multi-day events)
      for (final onStay in onStays) {
        try {
          if (onStay.checkInDate != null) {
            final startDate = DateTime(
              onStay.checkInDate!.year,
              onStay.checkInDate!.month,
              onStay.checkInDate!.day,
            );

            // Check if it has check-out date for multi-day stay
            if (onStay.checkOutDate != null) {
              final endDate = DateTime(
                onStay.checkOutDate!.year,
                onStay.checkOutDate!.month,
                onStay.checkOutDate!.day,
              );

              // Add OnStay to all dates in the range
              DateTime currentDate = startDate;
              while (currentDate.isBefore(endDate) ||
                  currentDate.isAtSameMomentAs(endDate)) {
                events[currentDate] = [...(events[currentDate] ?? []), onStay];
                currentDate = currentDate.add(const Duration(days: 1));
              }
            } else {
              // Single day stay
              events[startDate] = [...(events[startDate] ?? []), onStay];
            }
          }
        } catch (e) {
          debugPrint('Error processing OnStay date: $e');
          continue;
        }
      }

      // Group Meetings by date
      for (final meeting in meetings) {
        try {
          final date = DateTime.parse(meeting.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          events[dateKey] = [...(events[dateKey] ?? []), meeting];
        } catch (e) {
          debugPrint('Error processing Meeting date: $e');
          continue;
        }
      }

      // Group Options by date
      for (final option in options) {
        try {
          if (option.date != null) {
            final date = option.date!;
            final dateKey = DateTime(date.year, date.month, date.day);
            events[dateKey] = [...(events[dateKey] ?? []), option];
          }
        } catch (e) {
          debugPrint('Error processing Option date: $e');
          continue;
        }
      }

      // Group Direct Bookings by date (handle multi-day events)
      for (final directBooking in directBookings) {
        try {
          if (directBooking.date != null) {
            final startDate = DateTime(
              directBooking.date!.year,
              directBooking.date!.month,
              directBooking.date!.day,
            );

            // Check if it's a multi-day booking
            if (directBooking.isMultiDay && directBooking.endDate != null) {
              final endDate = DateTime(
                directBooking.endDate!.year,
                directBooking.endDate!.month,
                directBooking.endDate!.day,
              );

              // Add DirectBooking to all dates in the range
              DateTime currentDate = startDate;
              while (currentDate.isBefore(endDate) ||
                  currentDate.isAtSameMomentAs(endDate)) {
                events[currentDate] = [
                  ...(events[currentDate] ?? []),
                  directBooking
                ];
                currentDate = currentDate.add(const Duration(days: 1));
              }
            } else {
              // Single day booking
              events[startDate] = [...(events[startDate] ?? []), directBooking];
            }
          }
        } catch (e) {
          debugPrint('Error processing DirectBooking date: $e');
          continue;
        }
      }

      // Group Direct Options by date
      for (final directOption in directOptions) {
        try {
          if (directOption.date != null) {
            final date = DateTime(
              directOption.date!.year,
              directOption.date!.month,
              directOption.date!.day,
            );
            events[date] = [...(events[date] ?? []), directOption];
          }
        } catch (e) {
          debugPrint('Error processing DirectOption date: $e');
          continue;
        }
      }

      // Group Polaroids by date
      for (final polaroid in polaroids) {
        try {
          final date = DateTime.parse(polaroid.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          events[dateKey] = [...(events[dateKey] ?? []), polaroid];
        } catch (e) {
          debugPrint('Error processing Polaroid date: $e');
          continue;
        }
      }

      // Group AI Jobs by date
      for (final aiJob in aiJobs) {
        try {
          if (aiJob.date != null) {
            final date = DateTime(
              aiJob.date!.year,
              aiJob.date!.month,
              aiJob.date!.day,
            );
            events[date] = [...(events[date] ?? []), aiJob];
          }
        } catch (e) {
          debugPrint('Error processing AiJob date: $e');
          continue;
        }
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });

      debugPrint(
          '📅 Preview Calendar: Loaded ${events.length} event dates with total events: ${events.values.fold(0, (sum, list) => sum + list.length)}');
    } catch (e) {
      debugPrint('❌ Preview Calendar: Error loading events: $e');
      setState(() {
        _error = 'Failed to load events: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<Event>> _getEventsForCalendarPreview() async {
    try {
      final eventsService = EventsService();
      final allEvents = await eventsService.getEventsWithRawData();
      
      // Get current user's email
      final authService = AuthService();
      final currentUser = authService.currentUser;
      if (currentUser?.email == null) {
        return [];
      }
      
      final userEmail = currentUser!.email!;
      
      // Filter events where user is model, agent, or creator
      final filteredEvents = allEvents.where((eventData) {
        final modelEmail = eventData['model_email'] as String?;
        final agentEmail = eventData['agent_email'] as String?;
        final creatorEmail = eventData['creator_email'] as String?;
        
        return modelEmail == userEmail || 
               agentEmail == userEmail || 
               creatorEmail == userEmail;
      }).toList();
      
      // Convert to Event objects
      return filteredEvents.map((eventData) => Event.fromJson(eventData)).toList();
    } catch (e) {
      debugPrint('Error loading events for calendar preview: $e');
      return [];
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  String _getEventTitle(dynamic event) {
    if (event is Job) {
      return event.clientName;
    } else if (event is Casting) {
      return event.clientName ?? 'Casting';
    } else if (event is Test) {
      return event.clientName ?? 'Test';
    } else if (event is Polaroid) {
      return event.clientName;
    } else if (event is Meeting) {
      return event.clientName;
    } else if (event is OnStay) {
      return event.locationName;
    } else if (event is DirectBooking) {
      return event.clientName;
    } else if (event is DirectOptions) {
      return event.clientName;
    } else if (event is Event && event.type == EventType.directOption) {
      return event.clientName ?? 'Direct Option';
    } else if (event is Option) {
      return event.clientName;
    } else if (event is Event && event.type == EventType.option) {
      return event.clientName ?? 'Option';
    } else if (event is AiJob) {
      return event.clientName;
    } else if (event is Event) {
      // Handle generic Event objects (like OTHER events)
      if (event.clientName != null && event.clientName!.isNotEmpty) {
        return event.clientName!;
      } else if (event.additionalData != null &&
          event.additionalData!['event_name'] != null) {
        return event.additionalData!['event_name'];
      } else {
        return event.type.displayName;
      }
    }
    return 'Untitled';
  }

  String _getTruncatedEventTitle(dynamic event) {
    String title = _getEventTitle(event);
    // Smart truncation for better readability - allow more characters
    if (title.length > 8) {
      // Try to truncate at word boundary or use ellipsis for better clarity
      if (title.contains(' ') && title.indexOf(' ') <= 6) {
        return title.substring(0, title.indexOf(' '));
      }
      return '${title.substring(0, 6)}..';
    }
    return title;
  }

  String _getEventType(dynamic event) {
    if (event is Job) return 'Job';
    if (event is Casting) return 'Casting';
    if (event is Test) return 'Test';
    if (event is OnStay) return 'On Stay';
    if (event is Polaroid) return 'Polaroids';
    if (event is Meeting) return 'Meeting';
    if (event is DirectBooking) return 'Direct Booking';
    if (event is DirectOptions) return 'Direct Option';
    if (event is Event && event.type == EventType.directOption) return 'Direct Option';
    if (event is Option) return 'Option';
    if (event is Event && event.type == EventType.option) return 'Option';
    if (event is AiJob) return 'AI Job';
    if (event is Event) {
      switch (event.type) {
        case EventType.job:
          return 'Job';
        case EventType.casting:
          return 'Casting';
        case EventType.test:
          return 'Test';
        case EventType.option:
          return 'Option';
        case EventType.directBooking:
          return 'Direct Booking';
        case EventType.directOption:
          return 'Direct Option';
        case EventType.onStay:
          return 'On Stay';
        case EventType.polaroids:
          return 'Polaroids';
        case EventType.meeting:
          return 'Meeting';
        default:
          return 'Event';
      }
    }
    return 'Event';
  }

  String _getEventTime(dynamic event) {
    if (event is Job && event.time != null) {
      return event.time!;
    } else if (event is Event && event.startTime != null) {
      return event.startTime!;
    }
    return 'All day';
  }

  String _getEventLocation(dynamic event) {
    if (event is Job) {
      return event.location.isEmpty ? 'No location specified' : event.location;
    } else if (event is Casting) {
      return event.location ?? 'No location specified';
    } else if (event is Test) {
      return event.location ?? 'No location specified';
    } else if (event is Event) {
      return event.location ?? 'No location specified';
    }
    return 'No location specified';
  }

  Color _getEventColor(dynamic event) {
    if (event is Job) return Colors.blue;
    if (event is Casting) return Colors.purple;
    if (event is Test) return Colors.orange;
    if (event is Polaroid) return Colors.pink;
    if (event is Meeting) return Colors.amber;
    if (event is OnStay) return Colors.indigo;
    if (event is DirectBooking) return Colors.red;
    if (event is DirectOptions) return Colors.teal;
    if (event is Event && event.type == EventType.directOption) return Colors.teal;
    if (event is Option) return Colors.green;
    if (event is Event && event.type == EventType.option) return Colors.green;
    if (event is AiJob) return Colors.cyan;
    if (event is Event) {
      switch (event.type) {
        case EventType.job:
          return Colors.blue;
        case EventType.casting:
          return Colors.purple;
        case EventType.test:
          return Colors.orange;
        case EventType.option:
          return Colors.green;
        case EventType.directBooking:
          return Colors.red;
        case EventType.directOption:
          return Colors.teal;
        case EventType.onStay:
          return Colors.indigo;
        case EventType.polaroids:
          return Colors.pink;
        case EventType.meeting:
          return Colors.amber;
        default:
          return Colors.grey;
      }
    }
    return Colors.grey;
  }

  Widget _buildCalendarDay(DateTime day, bool isToday, bool isSelected,
      {bool isOutside = false}) {
    final events = _getEventsForDay(day);
    final hasEvents = events.isNotEmpty;

    Color? backgroundColor;
    Color textColor = Colors.white;
    Color? borderColor;

    if (isSelected) {
      backgroundColor = AppTheme.goldColor;
      textColor = Colors.black;
    } else if (isToday) {
      backgroundColor = AppTheme.goldColor.withValues(alpha: 0.7);
      textColor = Colors.black;
    } else if (hasEvents) {
      // Show event-based background color for days with events
      final primaryEventColor = _getEventColor(events.first);
      if (events.length == 1) {
        // Single event - use event color with transparency
        backgroundColor = primaryEventColor.withValues(alpha: 0.3);
        borderColor = primaryEventColor.withValues(alpha: 0.8);
        textColor = Colors.white;
      } else {
        // Multiple events - use a mixed color approach
        backgroundColor = primaryEventColor.withValues(alpha: 0.2);
        borderColor = primaryEventColor.withValues(alpha: 0.6);
        textColor = Colors.white;
      }
    } else if (isOutside) {
      textColor = Colors.white.withValues(alpha: 0.4);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Get screen size for responsive design
        final screenWidth = MediaQuery.of(context).size.width;
        final isVerySmall = screenWidth < 360;
        final isSmall = screenWidth < 600;
        final isMobile = screenWidth < 768;

        // Responsive sizing for welcome page calendar - improved for better readability
        double cellWidth = isVerySmall
            ? 40
            : isSmall
                ? 45
                : isMobile
                    ? 50
                    : 55;
        double cellHeight = isVerySmall
            ? 65
            : isSmall
                ? 70
                : isMobile
                    ? 75
                    : 80;
        double dayFontSize = isVerySmall
            ? 12
            : isSmall
                ? 14
                : 16;
        double eventFontSize = isVerySmall
            ? 7
            : isSmall
                ? 8
                : isMobile
                    ? 9
                    : 10;

        return Container(
          margin: EdgeInsets.all(isVerySmall ? 1 : 2),
          padding: EdgeInsets.symmetric(
              vertical: isVerySmall ? 2 : 3, horizontal: isVerySmall ? 1 : 2),
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(isVerySmall ? 4 : 6),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
            // Add subtle shadow for days with events to make them stand out
            boxShadow: hasEvents && !isSelected && !isToday
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Day number
              Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : hasEvents
                          ? FontWeight.w600
                          : FontWeight.normal,
                  fontSize: dayFontSize,
                  // Add text shadow for better readability on colored backgrounds
                  shadows: hasEvents && !isSelected && !isToday
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0.5, 0.5),
                            blurRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),

              // Event indicators
              if (hasEvents) ...[
                SizedBox(height: isVerySmall ? 1 : 2),
                Expanded(
                  child: ClipRect(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: isVerySmall ? 1 : 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (events.length == 1) ...[
                            // Show single event name with appealing styling
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _getTruncatedEventTitle(events.first),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: eventFontSize +
                                        1, // Slightly larger for better readability
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                    letterSpacing:
                                        0.3, // Better letter spacing for clarity
                                    // Strong text shadow for maximum appeal and readability
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.8),
                                        offset: const Offset(0.5, 0.5),
                                        blurRadius: 1.5,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Show event count for multiple events with indicator
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _getEventColor(events.first)
                                      .withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${events.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: eventFontSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showDayEventsDialog(DateTime selectedDate, List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Events for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      color: Colors.grey[800],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getEventColor(event),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          _getEventTitle(event),
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getEventType(event),
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            if (_getEventTime(event) != 'All day')
                              Text(
                                _getEventTime(event),
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          // Just show event details without edit option
                          _showEventDetailsDialog(context, event);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddEventDialog(selectedDate);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEventDetailsDialog(BuildContext context, dynamic event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          _getEventTitle(event),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildEventDetails(event),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditEvent(event);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventDetails(dynamic event) {
    List<Widget> details = [];

    // Event Type
    details.addAll([
      _buildDetailRow('Type', _getEventType(event)),
      const SizedBox(height: 12),
    ]);

    // Date and Time
    if (event is Job) {
      final date = DateTime.tryParse(event.date);
      details.addAll([
        _buildDetailRow(
            'Date',
            date != null
                ? DateFormat('EEEE, MMMM d, yyyy').format(date)
                : event.date),
        const SizedBox(height: 8),
      ]);
      if (event.time != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${event.time}${event.endTime != null ? ' - ${event.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    } else if (event is Casting) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date)),
        const SizedBox(height: 8),
      ]);
    } else if (event is Test) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date)),
        const SizedBox(height: 8),
      ]);
    } else if (event is Event && event.date != null) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date!)),
        const SizedBox(height: 8),
      ]);
      if (event.startTime != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${event.startTime}${event.endTime != null ? ' - ${event.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    }

    // Location
    final location = _getEventLocation(event);
    if (location.isNotEmpty &&
        location != 'No location' &&
        location != 'No location specified') {
      details.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Location:',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ClickableContactInfo(
                text: location,
                type: ContactType.location,
                showIcon: false,
                textColor: Colors.blue[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ]);
    }

    // Event-specific details
    if (event is Job) {
      details.addAll(_buildJobDetails(event));
    } else if (event is Casting) {
      details.addAll(_buildCastingDetails(event));
    } else if (event is Test) {
      details.addAll(_buildTestDetails(event));
    } else if (event is Polaroid) {
      details.addAll(_buildPolaroidDetails(event));
    } else if (event is Meeting) {
      details.addAll(_buildMeetingDetails(event));
    } else if (event is OnStay) {
      details.addAll(_buildOnStayDetails(event));
    } else if (event is DirectBooking) {
      details.addAll(_buildDirectBookingDetails(event));
    } else if (event is DirectOptions) {
      details.addAll(_buildDirectOptionsDetails(event));
    } else if (event is Option) {
      details.addAll(_buildOptionDetails(event));
    } else if (event is AiJob) {
      details.addAll(_buildAiJobDetails(event));
    } else if (event is Event) {
      details.addAll(_buildGenericEventDetails(event));
    }

    return details;
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentRow(String label, String agentId) {
    // Get agent from cache
    final agent = _agentCache[agentId];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Text(
                agent?.name ?? 'Unknown Agent',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              if (agent != null)
                InkWell(
                  onTap: () => _sendWhatsAppToAgent(agent),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  void _sendWhatsAppToAgent(Agent agent) async {
    // Check if agent has a phone number
    if (agent.phone == null || agent.phone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No phone number available for ${agent.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Use the same approach as agents page
    final whatsappUrl = 'https://wa.me/${_cleanPhoneNumber(agent.phone!)}';

    // Store context before async gap
    final currentContext = context;
    try {
      await _launchUrl(whatsappUrl);
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEventDialog(DateTime selectedDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Add New Event',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Event Type',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  'Select event type',
                  style: TextStyle(color: Colors.grey),
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'option', child: Text('Option')),
                  DropdownMenuItem(value: 'job', child: Text('Job')),
                  DropdownMenuItem(
                      value: 'directOption', child: Text('Direct Option')),
                  DropdownMenuItem(
                      value: 'directBooking', child: Text('Direct Booking')),
                  DropdownMenuItem(value: 'casting', child: Text('Casting')),
                  DropdownMenuItem(value: 'onStay', child: Text('On Stay')),
                  DropdownMenuItem(value: 'test', child: Text('Test')),
                  DropdownMenuItem(
                      value: 'polaroids', child: Text('Polaroids')),
                  DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    Navigator.pop(context);
                    _navigateToEventCreation(value, selectedDate);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Will be scheduled for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToEventCreation(String eventType, DateTime selectedDate) {
    switch (eventType) {
      case 'option':
        Navigator.pushNamed(
          context,
          '/new-option',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'job':
        Navigator.pushNamed(
          context,
          '/new-job',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'directOption':
        Navigator.pushNamed(
          context,
          '/new-direct-option',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'directBooking':
        Navigator.pushNamed(
          context,
          '/new-direct-booking',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'casting':
        Navigator.pushNamed(
          context,
          '/new-casting',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'onStay':
        Navigator.pushNamed(
          context,
          '/new-on-stay',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'test':
        Navigator.pushNamed(
          context,
          '/new-test',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'polaroids':
        Navigator.pushNamed(
          context,
          '/new-polaroid',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'meeting':
        Navigator.pushNamed(
          context,
          '/new-meeting',
          arguments: {'preselectedDate': selectedDate},
        ).then((_) => _loadEvents());
        break;
      case 'other':
        Navigator.pushNamed(
          context,
          '/new-event',
          arguments: {
            'preselectedDate': selectedDate,
            'eventType': EventType.other
          },
        ).then((_) => _loadEvents());
        break;
      default:
        Navigator.pushNamed(
          context,
          '/new-event',
          arguments: {
            'preselectedDate': selectedDate,
            'eventType': EventType.other
          },
        ).then((_) => _loadEvents());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFullCalendar) {
      return _buildPreviewCalendar();
    }

    return _buildFullCalendar();
  }

  Widget _buildPreviewCalendar() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Month header
          LayoutBuilder(
            builder: (context, constraints) {
              final isVerySmall = constraints.maxWidth < 200;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getMonthName(currentMonth),
                      style: TextStyle(
                        fontSize: isVerySmall ? 14 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentYear.toString(),
                    style: TextStyle(
                      fontSize: isVerySmall ? 12 : 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Weekday headers
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallMobile = screenWidth < 360;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((day) => Flexible(
                          child: SizedBox(
                            width: isSmallMobile ? 16 : 20,
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallMobile ? 9 : 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),

          // Calendar grid - scrollable for one month
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallMobile = screenWidth < 360;
              final calendarHeight = isSmallMobile ? 120.0 : 140.0;
              final dateWidth = isSmallMobile ? 50.0 : 60.0;
              final marginRight = isSmallMobile ? 6.0 : 8.0;

              return SizedBox(
                height: calendarHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      DateTime(currentYear, currentMonth + 1, 0).day,
                      (index) {
                        final dayNumber = index + 1;
                        final cellDate =
                            DateTime(currentYear, currentMonth, dayNumber);
                        final isToday = cellDate.day == now.day &&
                            cellDate.month == now.month &&
                            cellDate.year == now.year;
                        final isPast = cellDate
                            .isBefore(DateTime(now.year, now.month, now.day));
                        final events = _getEventsForDay(cellDate);
                        final hasEvents = events.isNotEmpty;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDay = cellDate;
                            });
                            if (hasEvents) {
                              _showDayEventsDialog(cellDate, events);
                            } else {
                              _showAddEventDialog(cellDate);
                            }
                          },
                          child: Container(
                            width: dateWidth,
                            margin: EdgeInsets.only(right: marginRight),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppTheme.goldColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallMobile ? 2 : 4,
                                vertical: isSmallMobile ? 4 : 6,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Weekday
                                  Text(
                                    _getWeekdayName(cellDate.weekday),
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 7 : 9,
                                      color: isToday
                                          ? Colors.black
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),

                                  // Day number
                                  Text(
                                    dayNumber.toString(),
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 14 : 16,
                                      fontWeight: isToday
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isToday
                                          ? Colors.black
                                          : isPast
                                              ? Colors.white
                                                  .withValues(alpha: 0.4)
                                              : Colors.white,
                                    ),
                                  ),

                                  // Event indicators section
                                  SizedBox(
                                    height: isSmallMobile ? 18 : 22,
                                    child: hasEvents
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (events.length == 1) ...[
                                                Text(
                                                  _getEventTitle(events.first),
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSmallMobile ? 7 : 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: isToday
                                                        ? Colors.black
                                                        : Colors.white,
                                                    height: 1.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ] else ...[
                                                Text(
                                                  '+${events.length}',
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSmallMobile ? 8 : 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isToday
                                                        ? Colors.black
                                                        : Colors.white,
                                                    height: 1.0,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),

                                  // Month
                                  Text(
                                    _getMonthAbbr(currentMonth),
                                    style: TextStyle(
                                      fontSize: isSmallMobile ? 7 : 9,
                                      color: isToday
                                          ? Colors.black
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppTheme.goldColor, 'Today'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullCalendar() {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.goldColor),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Calendar header with add button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isVerySmall = constraints.maxWidth < 300;
                final isSmall = constraints.maxWidth < 400;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Your Schedule',
                        style: TextStyle(
                          fontSize: isVerySmall
                              ? 14
                              : isSmall
                                  ? 16
                                  : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Today button to jump to current date
                    ElevatedButton(
                      onPressed: () {
                        final today = DateTime.now();
                        setState(() {
                          _focusedDay = today;
                          _selectedDay = today;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldColor,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: isVerySmall ? 8 : 12,
                          vertical: isVerySmall ? 4 : 6,
                        ),
                        textStyle: TextStyle(
                          fontSize: isVerySmall ? 10 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Today'),
                    ),
                    const SizedBox(width: 8),
                    if (isVerySmall)
                      // Very small screens: Icon only button
                      ElevatedButton(
                        onPressed: () =>
                            _showAddEventDialog(_selectedDay ?? DateTime.now()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.add, size: 16),
                      )
                    else if (isSmall)
                      // Small screens: Compact button
                      ElevatedButton(
                        onPressed: () =>
                            _showAddEventDialog(_selectedDay ?? DateTime.now()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                        child: const Text('Add'),
                      )
                    else
                      // Normal screens: Full button
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showAddEventDialog(_selectedDay ?? DateTime.now()),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Table Calendar with responsive constraints
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isVerySmall = screenWidth < 300;
              final isSmall = screenWidth < 400;

              return SizedBox(
                width: constraints.maxWidth,
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    markersMaxCount:
                        0, // Disable default markers since we use custom builders
                    todayDecoration: const BoxDecoration(
                      color: Colors.transparent, // Handled by custom builder
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.transparent, // Handled by custom builder
                    ),
                    defaultDecoration: const BoxDecoration(
                      color: Colors.transparent, // Handled by custom builder
                    ),
                    outsideDaysVisible: false,
                    canMarkersOverflow: false,
                    weekendTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall ? 12 : 14,
                    ),
                    defaultTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall ? 12 : 14,
                    ),
                    cellMargin: EdgeInsets.all(isVerySmall ? 2 : 3),
                    cellPadding: const EdgeInsets.all(0),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, false, false);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, true, false);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, false, true);
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(day, false, false,
                          isOutside: true);
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: isVerySmall
                          ? 14
                          : isSmall
                              ? 15
                              : 16,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: isVerySmall ? 20 : 24,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: isVerySmall ? 20 : 24,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: isVerySmall ? 10 : 12,
                    ),
                    weekendStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: isVerySmall ? 10 : 12,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });

                    // Show events for the selected day
                    final events = _getEventsForDay(selectedDay);
                    if (events.isNotEmpty) {
                      _showDayEventsDialog(selectedDay, events);
                    } else {
                      _showAddEventDialog(selectedDay);
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Event-specific detail builders
  List<Widget> _buildJobDetails(Job job) {
    List<Widget> details = [];

    if (job.type.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Job Type', job.type),
        const SizedBox(height: 8),
      ]);
    }

    if (job.rate > 0) {
      details.addAll([
        _buildDetailRow(
            'Rate', '${job.currency ?? 'USD'} ${job.rate.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (job.extraHours != null && job.extraHours! > 0) {
      details.addAll([
        _buildDetailRow(
            'Extra Hours', '${job.extraHours!.toStringAsFixed(1)} hours'),
        const SizedBox(height: 8),
      ]);
    }

    if (job.bookingAgent != null && job.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', job.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (job.status != null && job.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', job.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (job.paymentStatus != null && job.paymentStatus!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Payment', job.paymentStatus!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (job.notes != null && job.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', job.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildCastingDetails(Casting casting) {
    List<Widget> details = [];

    // Parse description to extract individual fields
    Map<String, String> parsedData = _parseDescriptionData(casting.description);

    // Job Type (from description)
    if (parsedData['jobType'] != null) {
      details.addAll([
        _buildDetailRow('Description', parsedData['jobType']!),
        const SizedBox(height: 8),
      ]);
    }

    // Time (combine start and end time from description)
    String? startTime = parsedData['startTime'];
    String? endTime = parsedData['endTime'];

    if (startTime != null && endTime != null) {
      details.addAll([
        _buildDetailRow('Time', '$startTime - $endTime'),
        const SizedBox(height: 8),
      ]);
    } else if (startTime != null) {
      details.addAll([
        _buildDetailRow('Start Time', startTime),
        const SizedBox(height: 8),
      ]);
    } else if (endTime != null) {
      details.addAll([
        _buildDetailRow('End Time', endTime),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information (from description)
    String? agentId = parsedData['agentId'];
    if (agentId != null) {
      details.addAll([
        _buildAgentRow('Agent', agentId),
        const SizedBox(height: 8),
      ]);
    }

    // Notes (from description)
    if (parsedData['notes'] != null) {
      details.addAll([
        _buildDetailRow('Notes', parsedData['notes']!),
        const SizedBox(height: 8),
      ]);
    }

    // Date
    details.addAll([
      _buildDetailRow(
          'Date', DateFormat('EEEE, MMMM d, yyyy').format(casting.date)),
      const SizedBox(height: 8),
    ]);

    // Location
    if (casting.location != null && casting.location!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Location', casting.location!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    details.addAll([
      _buildDetailRow('Status', casting.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    return details;
  }

  Map<String, String> _parseDescriptionData(String? description) {
    Map<String, String> data = {};

    if (description == null || description.isEmpty) {
      return data;
    }

    final lines = description.split('\n');
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('Job Type: ')) {
        data['jobType'] = line.substring('Job Type: '.length);
      } else if (line.startsWith('Start Time: ')) {
        data['startTime'] = line.substring('Start Time: '.length);
      } else if (line.startsWith('End Time: ')) {
        data['endTime'] = line.substring('End Time: '.length);
      } else if (line.startsWith('Agent ID: ')) {
        data['agentId'] = line.substring('Agent ID: '.length);
      } else if (line.startsWith('Notes: ')) {
        data['notes'] = line.substring('Notes: '.length);
      }
    }

    return data;
  }

  String? _getAgentIdFromNotes(String? notes) {
    if (notes == null || notes.isEmpty) {
      return null;
    }

    final lines = notes.split('\n');
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('Agent ID: ')) {
        return line.substring('Agent ID: '.length);
      }
    }

    return null;
  }

  /// Extract only the "Additional Notes" part from structured OnStay notes
  String? _getCleanNotesFromOnStay(String? notes) {
    if (notes == null || notes.isEmpty) {
      return null;
    }

    // Split notes by double newlines to get individual sections
    final sections = notes.split('\n\n');

    for (final section in sections) {
      final trimmedSection = section.trim();
      if (trimmedSection.startsWith('Additional Notes: ')) {
        final cleanNotes = trimmedSection.substring(18).trim();
        return cleanNotes.isNotEmpty ? cleanNotes : null;
      }
    }

    // If no "Additional Notes" section found, check if the entire notes field
    // contains only unstructured text (no "Field: Value" patterns)
    final hasStructuredData =
        notes.contains(RegExp(r'^[A-Za-z\s]+:\s', multiLine: true));
    if (!hasStructuredData) {
      // Return the entire notes if it doesn't contain structured data
      return notes.trim().isNotEmpty ? notes.trim() : null;
    }

    return null;
  }

  Map<String, String> _parseTestDescriptionData(String? description) {
    Map<String, String> data = {};

    if (description == null || description.isEmpty) {
      return data;
    }

    final lines = description.split('\n\n');
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('Test Type: ')) {
        data['testType'] = line.substring('Test Type: '.length);
      } else if (line.startsWith('Rate: ')) {
        data['rate'] = line.substring('Rate: '.length);
      } else if (line.startsWith('Call Time: ')) {
        data['callTime'] = line.substring('Call Time: '.length);
      } else if (line.startsWith('Agent ID: ')) {
        data['agentId'] = line.substring('Agent ID: '.length);
      } else if (line.startsWith('Notes: ')) {
        data['notes'] = line.substring('Notes: '.length);
      }
    }

    return data;
  }

  List<Widget> _buildTestDetails(Test test) {
    List<Widget> details = [];

    // Parse description to extract individual fields
    Map<String, String> parsedData =
        _parseTestDescriptionData(test.description);

    // Test Type (from description)
    if (parsedData['testType'] != null) {
      details.addAll([
        _buildDetailRow('Test Type', parsedData['testType']!),
        const SizedBox(height: 8),
      ]);
    }

    // Rate (from description or model field)
    if (parsedData['rate'] != null) {
      details.addAll([
        _buildDetailRow('Rate', parsedData['rate']!),
        const SizedBox(height: 8),
      ]);
    } else if (test.rate != null && test.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${test.currency ?? 'USD'} ${test.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Call Time (from description)
    if (parsedData['callTime'] != null) {
      details.addAll([
        _buildDetailRow('Call Time', parsedData['callTime']!),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information (from description)
    final agentId = parsedData['agentId'];
    if (agentId != null) {
      details.addAll([
        _buildAgentRow('Agent', agentId),
        const SizedBox(height: 8),
      ]);
    }

    // Notes (from description)
    if (parsedData['notes'] != null) {
      details.addAll([
        _buildDetailRow('Notes', parsedData['notes']!),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', test.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    return details;
  }

  List<Widget> _buildPolaroidDetails(Polaroid polaroid) {
    List<Widget> details = [];

    if (polaroid.type != null && polaroid.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', polaroid.type!),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.rate != null && polaroid.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${polaroid.currency ?? 'USD'} ${polaroid.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.time != null && polaroid.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${polaroid.time}${polaroid.endTime != null ? ' - ${polaroid.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.bookingAgent != null && polaroid.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', polaroid.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.status != null && polaroid.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', polaroid.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (polaroid.notes != null && polaroid.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', polaroid.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildMeetingDetails(Meeting meeting) {
    List<Widget> details = [];

    if (meeting.type != null && meeting.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', meeting.type!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.time != null && meeting.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${meeting.time}${meeting.endTime != null ? ' - ${meeting.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    // Add agent information for meetings
    if (meeting.bookingAgent != null && meeting.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', meeting.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.email != null && meeting.email!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Email', meeting.email!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.phone != null && meeting.phone!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Phone', meeting.phone!),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.status != null && meeting.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', meeting.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (meeting.notes != null && meeting.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', meeting.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildOnStayDetails(OnStay onStay) {
    List<Widget> details = [];

    if (onStay.stayType != null && onStay.stayType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Stay Type', onStay.stayType!),
        const SizedBox(height: 8),
      ]);
    }

    if (onStay.address != null && onStay.address!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Address', onStay.address!),
        const SizedBox(height: 8),
      ]);
    }

    if (onStay.checkInDate != null) {
      details.addAll([
        _buildDetailRow(
            'Check-in', DateFormat('MMM d, yyyy').format(onStay.checkInDate!)),
        const SizedBox(height: 8),
      ]);
    }

    if (onStay.checkOutDate != null) {
      details.addAll([
        _buildDetailRow('Check-out',
            DateFormat('MMM d, yyyy').format(onStay.checkOutDate!)),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow(
          'Cost', '${onStay.currency} ${onStay.cost.toStringAsFixed(2)}'),
      const SizedBox(height: 8),
    ]);

    if (onStay.contactName != null && onStay.contactName!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Contact', onStay.contactName!),
        const SizedBox(height: 8),
      ]);
    }

    // Add agent information for on stays - check direct agentId field first, then fall back to notes
    String? agentId = onStay.agentId;
    if (agentId == null || agentId.isEmpty) {
      agentId = _getAgentIdFromNotes(onStay.notes);
    }
    if (agentId != null && agentId.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', agentId),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', onStay.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Add notes if they exist (extract clean notes only)
    final cleanNotes = _getCleanNotesFromOnStay(onStay.notes);
    if (cleanNotes != null) {
      details.addAll([
        _buildDetailRow('Notes', cleanNotes),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildDirectBookingDetails(DirectBooking directBooking) {
    List<Widget> details = [];

    if (directBooking.bookingType != null &&
        directBooking.bookingType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Booking Type', directBooking.bookingType!),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.rate != null && directBooking.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${directBooking.currency ?? 'USD'} ${directBooking.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.time != null && directBooking.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${directBooking.time}${directBooking.endTime != null ? ' - ${directBooking.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.bookingAgent != null &&
        directBooking.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', directBooking.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (directBooking.status != null && directBooking.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', directBooking.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Add notes if they exist
    if (directBooking.notes != null && directBooking.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', directBooking.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildDirectOptionsDetails(DirectOptions directOptions) {
    List<Widget> details = [];

    if (directOptions.optionType != null &&
        directOptions.optionType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Option Type', directOptions.optionType!),
        const SizedBox(height: 8),
      ]);
    }

    // Show Day Rate and Usage Rate separately (like in the screenshot)
    if (directOptions.rate != null && directOptions.rate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate',
            '${directOptions.currency ?? 'USD'} ${directOptions.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
      // For DirectOptions, usage rate is typically the same as day rate
      details.addAll([
        _buildDetailRow('Usage Rate',
            '${directOptions.currency ?? 'USD'} ${directOptions.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (directOptions.time != null && directOptions.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${directOptions.time}${directOptions.endTime != null ? ' - ${directOptions.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    // Use the new agent row with WhatsApp functionality
    if (directOptions.bookingAgent != null &&
        directOptions.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', directOptions.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (directOptions.status != null && directOptions.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', directOptions.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Add Payment Status
    if (directOptions.paymentStatus != null &&
        directOptions.paymentStatus!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Payment', directOptions.paymentStatus!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Add Notes
    if (directOptions.notes != null && directOptions.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', directOptions.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildOptionDetails(Option option) {
    List<Widget> details = [];

    if (option.type.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', option.type),
        const SizedBox(height: 8),
      ]);
    }

    if (option.rate != null && option.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${option.currency ?? 'USD'} ${option.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (option.time != null && option.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time',
            '${option.time}${option.endTime != null ? ' - ${option.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    if (option.extraHours != null && option.extraHours! > 0) {
      details.addAll([
        _buildDetailRow(
            'Extra Hours', '${option.extraHours!.toStringAsFixed(1)} hours'),
        const SizedBox(height: 8),
      ]);
    }

    // Add agent information for options
    if (option.agentId != null && option.agentId!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', option.agentId!),
        const SizedBox(height: 8),
      ]);
    }

    details.addAll([
      _buildDetailRow('Status', option.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    details.addAll([
      _buildDetailRow('Payment', option.paymentStatus.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    if (option.notes != null && option.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', option.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildGenericEventDetails(Event event) {
    List<Widget> details = [];

    if (event.dayRate != null && event.dayRate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate',
            '${event.currency ?? 'USD'} ${event.dayRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (event.usageRate != null && event.usageRate! > 0) {
      details.addAll([
        _buildDetailRow('Usage Rate',
            '${event.currency ?? 'USD'} ${event.usageRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Add agent information for generic events
    if (event.agentId != null && event.agentId!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', event.agentId!),
        const SizedBox(height: 8),
      ]);
    }

    if (event.status != null) {
      details.addAll([
        _buildDetailRow(
            'Status', event.status.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (event.paymentStatus != null) {
      details.addAll([
        _buildDetailRow('Payment',
            event.paymentStatus.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (event.notes != null && event.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', event.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  List<Widget> _buildAiJobDetails(AiJob aiJob) {
    List<Widget> details = [];

    if (aiJob.type != null && aiJob.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', aiJob.type!),
        const SizedBox(height: 8),
      ]);
    }

    if (aiJob.description != null && aiJob.description!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Description', aiJob.description!),
        const SizedBox(height: 8),
      ]);
    }

    if (aiJob.rate != null && aiJob.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${aiJob.currency ?? 'USD'} ${aiJob.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (aiJob.time != null && aiJob.time!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Time', aiJob.time!),
        const SizedBox(height: 8),
      ]);
    }

    // Add agent information for AI jobs
    if (aiJob.bookingAgent != null && aiJob.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', aiJob.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    if (aiJob.status != null && aiJob.status!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Status', aiJob.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (aiJob.paymentStatus != null && aiJob.paymentStatus!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Payment', aiJob.paymentStatus!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    if (aiJob.notes != null && aiJob.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', aiJob.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  void _navigateToEditEvent(dynamic event) {
    String route;
    Map<String, dynamic> arguments = {};

    if (event is Job) {
      route = '/new-job';
      arguments = {'existingJob': event};
    } else if (event is Casting) {
      route = '/new-casting';
      arguments = {'existingCasting': event};
    } else if (event is Test) {
      route = '/new-test';
      arguments = {'existingTest': event};
    } else if (event is Polaroid) {
      route = '/new-polaroid';
      arguments = {'existingPolaroid': event};
    } else if (event is Meeting) {
      route = '/new-meeting';
      arguments = {'existingMeeting': event};
    } else if (event is OnStay) {
      route = '/new-on-stay';
      arguments = {'existingOnStay': event};
    } else if (event is DirectBooking) {
      route = '/new-direct-booking';
      arguments = {'existingDirectBooking': event};
    } else if (event is DirectOptions) {
      route = '/new-direct-option';
      arguments = {'existingDirectOption': event};
    } else if (event is Option) {
      route = '/new-option';
      arguments = {'existingOption': event};
    } else if (event is AiJob) {
      route = '/new-ai-job';
      arguments = {'existingAiJob': event};
    } else if (event is Event) {
      route = '/new-event';
      arguments = {'existingEvent': event, 'eventType': event.type};
    } else {
      // Fallback for unknown event types
      return;
    }

    Navigator.pushNamed(context, route, arguments: arguments).then((_) {
      // Reload events after editing
      _loadEvents();
    });
  }
}
