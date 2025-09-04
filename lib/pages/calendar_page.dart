import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/job.dart';
import '../models/casting.dart';
import '../models/test.dart';
import '../models/event.dart';
import '../models/on_stay.dart';
import '../models/meeting.dart';
import '../models/option.dart';
import '../models/direct_booking.dart';
import '../models/direct_options.dart';
import '../models/polaroid.dart';
import '../models/ai_job.dart';
import '../models/agent.dart';
import '../services/jobs_service.dart';
import '../services/events_service.dart';
import '../services/on_stay_service.dart';
import '../services/meetings_service.dart';
import '../services/options_service.dart';
import '../services/direct_bookings_service.dart';
import '../services/direct_options_service.dart';
import '../services/polaroids_service.dart';
import '../services/ai_jobs_service.dart';
import '../services/agents_service.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _viewMode = 'month';
  bool _isLoading = true;
  String? _error;
  Map<DateTime, List<dynamic>> _events = {};
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  // Performance optimization flags
  bool _isDisposed = false;
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📅 CalendarPage.initState() - Calendar page initialized!');
    _selectedDay = _focusedDay;
    _loadAgents();
    _loadEvents();
  }

  Future<void> _loadAgents() async {
    try {
      final agentsService = AgentsService();
      final agents = await agentsService.getAgents();
      setState(() {
        _agentCache = {
          for (final agent in agents)
            if (agent.id != null) agent.id!: agent
        };
      });
    } catch (e) {
      debugPrint('Error loading agents: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Helper method to get all date keys for a date range (inclusive)
  List<DateTime> _getDateRangeKeys(DateTime startDate, DateTime? endDate) {
    final List<DateTime> dateKeys = [];
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    if (endDate == null) {
      // Single day event
      dateKeys.add(start);
    } else {
      // Multi-day event - include all days from start to end (inclusive)
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      DateTime current = start;

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        dateKeys.add(current);
        current = current.add(const Duration(days: 1));
      }
    }

    return dateKeys;
  }

  /// Get events for calendar - includes events where user is model, agent, or creator
  Future<List<Event>> _getEventsForCalendar() async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      final currentUserEmail = currentUser?.email;

      if (currentUserEmail == null) {
        debugPrint('📅 No current user email found for calendar events');
        return [];
      }

      debugPrint('📅 Loading calendar events for user: $currentUserEmail');
      final rawDocuments = await EventsService().getEventsWithRawData();
      debugPrint('📅 Total events fetched for calendar: ${rawDocuments.length}');

      // Filter events where current user is involved (model, agent, or creator)
      final relevantDocuments = rawDocuments.where((doc) {
        final modelEmail = doc['model_email']?.toString().toLowerCase();
        final agentEmail = doc['agent_email']?.toString().toLowerCase();
        final creatorEmail = doc['creator_email']?.toString().toLowerCase();
        final userEmail = currentUserEmail.toLowerCase();

        return modelEmail == userEmail || 
               agentEmail == userEmail || 
               creatorEmail == userEmail;
      }).toList();

      debugPrint('📅 Relevant events for calendar: ${relevantDocuments.length}');

      // Convert to Event objects
      final events = relevantDocuments.map<Event>((doc) => Event.fromJson(doc)).toList();
      
      debugPrint('📅 Calendar events loaded: ${events.length}');
      return events;
    } catch (e) {
      debugPrint('❌ Error loading calendar events: $e');
      return [];
    }
  }

  Future<void> _loadEvents() async {
    debugPrint('📅 CalendarPage._loadEvents() - Starting to load events...');

    // Prevent multiple simultaneous loads
    if (_isLoadingEvents || _isDisposed) {
      debugPrint(
          '📅 CalendarPage._loadEvents() - Skipping load (loading: $_isLoadingEvents, disposed: $_isDisposed)');
      return;
    }

    try {
      _isLoadingEvents = true;

      if (!_isDisposed) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      // Load events with timeout for older devices
      final futures = await Future.wait([
        JobsService.list().timeout(const Duration(seconds: 10)),
        Casting.list().timeout(const Duration(seconds: 10)),
        Test.list().timeout(const Duration(seconds: 10)),
        _getEventsForCalendar().timeout(const Duration(seconds: 10)),
        OnStayService.list().timeout(const Duration(seconds: 10)),
        MeetingsService.list().timeout(const Duration(seconds: 10)),
        OptionsService.list().timeout(const Duration(seconds: 10)),
        DirectBookingsService.list().timeout(const Duration(seconds: 10)),
        DirectOptionsService.list().timeout(const Duration(seconds: 10)),
        PolaroidsService.list().timeout(const Duration(seconds: 10)),
        AiJobsService.list().timeout(const Duration(seconds: 10)),
      ]).timeout(const Duration(seconds: 30));

      if (_isDisposed) return;

      final jobs = futures[0] as List<Job>;
      final castings = futures[1] as List<Casting>;
      final tests = futures[2] as List<Test>;
      final generalEvents = futures[3] as List<Event>;
      final onStays = futures[4] as List<OnStay>;
      final meetings = futures[5] as List<Meeting>;
      final options = futures[6] as List<Option>;
      final directBookings = futures[7] as List<DirectBooking>;
      final directOptions = futures[8] as List<DirectOptions>;
      final polaroids = futures[9] as List<Polaroid>;
      final aiJobs = futures[10] as List<AiJob>;

      // Use more memory-efficient map building
      final events = <DateTime, List<dynamic>>{};

      // Group jobs by date with better error handling (supports multi-day jobs)
      for (final job in jobs) {
        if (_isDisposed) return;
        try {
          final startDate = DateTime.parse(job.date);
          final endDate = job.endDateTime;

          // Get all date keys for this job (single day or multi-day)
          final dateKeys = _getDateRangeKeys(startDate, endDate);

          // Add job to all relevant dates
          for (final dateKey in dateKeys) {
            if (events[dateKey] == null) {
              events[dateKey] = [job];
            } else {
              events[dateKey]!.add(job);
            }
          }

          if (endDate != null) {
            debugPrint(
                '📅 Multi-day job: ${job.clientName} from ${job.date} to ${job.endDate} (${dateKeys.length} days)');
          }
        } catch (e) {
          debugPrint('Error parsing job date: ${job.date} - $e');
          continue;
        }
      }

      // Group castings by date with disposal check
      for (final casting in castings) {
        if (_isDisposed) return;
        try {
          final date = DateTime(
            casting.date.year,
            casting.date.month,
            casting.date.day,
          );
          if (events[date] == null) {
            events[date] = [casting];
          } else {
            events[date]!.add(casting);
          }
        } catch (e) {
          debugPrint('Error processing casting date: $e');
          continue;
        }
      }

      // Group tests by date with disposal check
      for (final test in tests) {
        if (_isDisposed) return;
        try {
          final date = DateTime(test.date.year, test.date.month, test.date.day);
          if (events[date] == null) {
            events[date] = [test];
          } else {
            events[date]!.add(test);
          }
        } catch (e) {
          debugPrint('Error processing test date: $e');
          continue;
        }
      }

      // Group general events by date with disposal check (supports multi-day events)
      for (final event in generalEvents) {
        if (_isDisposed) return;
        try {
          if (event.date != null) {
            final startDate = event.date!;
            final endDate = event.endDate;

            // Get all date keys for this event (single day or multi-day)
            final dateKeys = _getDateRangeKeys(startDate, endDate);

            // Add event to all relevant dates
            for (final dateKey in dateKeys) {
              if (events[dateKey] == null) {
                events[dateKey] = [event];
              } else {
                events[dateKey]!.add(event);
              }
            }

            if (endDate != null) {
              debugPrint(
                  '📅 Multi-day general event: ${event.clientName} from ${event.date} to ${event.endDate} (${dateKeys.length} days)');
            } else {
              debugPrint(
                  '📅 Processing general event: ${event.clientName} on ${event.date}');
            }
          } else {
            debugPrint('📅 General event has null date: ${event.clientName}');
          }
        } catch (e) {
          debugPrint('Error processing general event date: $e');
          continue;
        }
      }

      // Group OnStay events by date with disposal check (supports multi-day stays)
      for (final onStay in onStays) {
        if (_isDisposed) return;
        try {
          if (onStay.checkInDate != null) {
            final startDate = onStay.checkInDate!;
            final endDate = onStay.checkOutDate;

            // Get all date keys for this stay (single day or multi-day)
            final dateKeys = _getDateRangeKeys(startDate, endDate);

            // Add stay to all relevant dates
            for (final dateKey in dateKeys) {
              if (events[dateKey] == null) {
                events[dateKey] = [onStay];
              } else {
                events[dateKey]!.add(onStay);
              }
            }

            if (endDate != null) {
              debugPrint(
                  '📅 Multi-day OnStay: ${onStay.locationName} from ${onStay.checkInDate} to ${onStay.checkOutDate} (${dateKeys.length} days)');
            } else {
              debugPrint(
                  '📅 Processing OnStay event: ${onStay.locationName} on ${onStay.checkInDate}');
            }
          } else {
            debugPrint(
                '📅 OnStay event has null checkInDate: ${onStay.locationName}');
          }
        } catch (e) {
          debugPrint('Error processing OnStay event date: $e');
          continue;
        }
      }

      // Group Meetings by date with disposal check
      for (final meeting in meetings) {
        if (_isDisposed) return;
        try {
          final date = DateTime.parse(meeting.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          debugPrint(
              '📅 Processing Meeting event: ${meeting.clientName} on $date -> dateKey: $dateKey');
          if (events[dateKey] == null) {
            events[dateKey] = [meeting];
          } else {
            events[dateKey]!.add(meeting);
          }
        } catch (e) {
          debugPrint('Error processing Meeting event date: $e');
          continue;
        }
      }

      // Group Options by date with disposal check
      for (final option in options) {
        if (_isDisposed) return;
        try {
          final date = DateTime.parse(option.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          debugPrint(
              '📅 Processing Option event: ${option.clientName} on $date -> dateKey: $dateKey');
          if (events[dateKey] == null) {
            events[dateKey] = [option];
          } else {
            events[dateKey]!.add(option);
          }
        } catch (e) {
          debugPrint('Error processing Option event date: $e');
          continue;
        }
      }

      // Group Direct Bookings by date with disposal check (supports multi-day bookings)
      for (final directBooking in directBookings) {
        if (_isDisposed) return;
        try {
          if (directBooking.date != null) {
            final startDate = directBooking.date!;
            final endDate = directBooking.endDateTime;

            // Get all date keys for this booking (single day or multi-day)
            final dateKeys = _getDateRangeKeys(startDate, endDate);

            // Add booking to all relevant dates
            for (final dateKey in dateKeys) {
              if (events[dateKey] == null) {
                events[dateKey] = [directBooking];
              } else {
                events[dateKey]!.add(directBooking);
              }
            }

            if (endDate != null) {
              debugPrint(
                  '📅 Multi-day DirectBooking: ${directBooking.clientName} from ${directBooking.date} to ${directBooking.endDate} (${dateKeys.length} days)');
            } else {
              debugPrint(
                  '📅 Processing DirectBooking event: ${directBooking.clientName} on ${directBooking.date}');
            }
          } else {
            debugPrint(
                '📅 DirectBooking event has null date: ${directBooking.clientName}');
          }
        } catch (e) {
          debugPrint('Error processing DirectBooking event date: $e');
          continue;
        }
      }

      // Group Direct Options by date with disposal check
      for (final directOption in directOptions) {
        if (_isDisposed) return;
        try {
          if (directOption.date != null) {
            final date = DateTime(
              directOption.date!.year,
              directOption.date!.month,
              directOption.date!.day,
            );
            debugPrint(
                '📅 Processing DirectOption event: ${directOption.clientName} on ${directOption.date} -> dateKey: $date');
            if (events[date] == null) {
              events[date] = [directOption];
            } else {
              events[date]!.add(directOption);
            }
          } else {
            debugPrint(
                '📅 DirectOption event has null date: ${directOption.clientName}');
          }
        } catch (e) {
          debugPrint('Error processing DirectOption event date: $e');
          continue;
        }
      }

      // Group Polaroids by date with disposal check
      for (final polaroid in polaroids) {
        if (_isDisposed) return;
        try {
          final date = DateTime.parse(polaroid.date);
          final dateKey = DateTime(date.year, date.month, date.day);
          debugPrint(
              '📅 Processing Polaroid event: ${polaroid.clientName} on $date -> dateKey: $dateKey');
          if (events[dateKey] == null) {
            events[dateKey] = [polaroid];
          } else {
            events[dateKey]!.add(polaroid);
          }
        } catch (e) {
          debugPrint('Error processing Polaroid event date: $e');
          continue;
        }
      }

      // Group AI Jobs by date with disposal check
      for (final aiJob in aiJobs) {
        if (_isDisposed) return;
        try {
          if (aiJob.date != null) {
            final date = DateTime(
              aiJob.date!.year,
              aiJob.date!.month,
              aiJob.date!.day,
            );
            debugPrint(
                '📅 Processing AiJob event: ${aiJob.clientName} on ${aiJob.date} -> dateKey: $date');
            if (events[date] == null) {
              events[date] = [aiJob];
            } else {
              events[date]!.add(aiJob);
            }
          } else {
            debugPrint('📅 AiJob event has null date: ${aiJob.clientName}');
          }
        } catch (e) {
          debugPrint('Error processing AiJob event date: $e');
          continue;
        }
      }

      if (!_isDisposed) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
        debugPrint(
            '📅 CalendarPage: Loaded ${events.length} event dates with total events: ${events.values.fold(0, (sum, list) => sum + list.length)}');
        debugPrint(
            '📅 CalendarPage: Event dates: ${events.keys.map((date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}').join(', ')}');

        // Debug: Check if we have events for the current month
        final now = DateTime.now();
        final currentMonthEvents = events.keys
            .where((date) => date.year == now.year && date.month == now.month)
            .toList();
        debugPrint(
            '📅 CalendarPage: Events in current month (${now.year}-${now.month}): ${currentMonthEvents.length}');
        for (final date in currentMonthEvents) {
          final dayEvents = events[date] ?? [];
          debugPrint(
              '📅 CalendarPage: ${date.day}/${date.month} has ${dayEvents.length} events: ${dayEvents.map((e) => e is Event ? e.clientName : e.toString()).join(', ')}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading events: $e');
      if (!_isDisposed) {
        setState(() {
          _error = 'Failed to load events. Please try again.';
          _isLoading = false;
        });
      }
    } finally {
      _isLoadingEvents = false;
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final events = _events[dateKey] ?? [];
    if (events.isNotEmpty) {
      debugPrint(
          '📅 CalendarPage._getEventsForDay: Found ${events.length} events for $dateKey: ${events.map((e) => e is Event ? e.clientName : e.toString()).join(', ')}');
    }
    return events;
  }

  void _showDayEventsDialog(DateTime selectedDate, List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Events for ${DateFormat('MMM d, yyyy').format(selectedDate)}',
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
                          _showEventDetails(context, event);
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
      default:
        Navigator.pushNamed(
          context,
          '/new-event',
          arguments: {'preselectedDate': selectedDate, 'eventType': eventType},
        ).then((_) => _loadEvents());
        break;
    }
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
    if (event is Option) return Colors.green;
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

  String _getEventType(dynamic event) {
    if (event is Job) return 'Job';
    if (event is Casting) return 'Casting';
    if (event is Test) return 'Test';
    if (event is Polaroid) return 'Polaroid';
    if (event is Meeting) return 'Meeting';
    if (event is OnStay) return 'On Stay';
    if (event is DirectBooking) return 'Direct Booking';
    if (event is DirectOptions) return 'Direct Option';
    if (event is Option) return 'Option';
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
    } else if (event is Option) {
      return event.clientName;
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
        return _getEventType(event);
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

  String _getEventLocation(dynamic event) {
    if (event is Job) {
      return event.location.isEmpty ? 'No location specified' : event.location;
    } else if (event is Casting) {
      return event.location ?? 'No location specified';
    } else if (event is Test) {
      return event.location ?? 'No location specified';
    } else if (event is Event) {
      return event.location ?? 'No location specified';
    } else if (event is DirectBooking) {
      return event.location?.isEmpty == false
          ? event.location!
          : 'No location specified';
    } else if (event is DirectOptions) {
      return event.location ?? 'No location specified';
    } else if (event is Meeting) {
      return event.location ?? 'No location specified';
    } else if (event is OnStay) {
      return event.address?.isEmpty == false
          ? event.address!
          : 'No location specified';
    } else if (event is Polaroid) {
      return event.location ?? 'No location specified';
    } else if (event is AiJob) {
      return event.location ?? 'No location specified';
    }
    return 'No location specified';
  }

  String? _getEventDescription(dynamic event) {
    if (event is Job) {
      return event.notes;
    } else if (event is Event) {
      return event.notes;
    } else if (event is DirectBooking) {
      return event.notes;
    } else if (event is DirectOptions) {
      return event.notes;
    } else if (event is Meeting) {
      return event.notes;
    } else if (event is OnStay) {
      return event.notes;
    } else if (event is AiJob) {
      return event.notes;
    }
    return null;
  }

  Widget _buildCalendarDay(DateTime day, bool isToday, bool isSelected,
      {bool isOutside = false}) {
    // Early return for disposed state
    if (_isDisposed) return const SizedBox.shrink();

    final events = _getEventsForDay(day);
    final hasEvents = events.isNotEmpty;

    // Pre-calculate colors to avoid repeated calculations
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

    // Cache screen width to avoid repeated MediaQuery calls
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 360;
    final isSmall = screenWidth < 600;
    final isMobile = screenWidth < 768;

    // Pre-calculate all sizes to improve performance
    final cellWidth = isVerySmall
        ? 40.0
        : isSmall
            ? 45.0
            : isMobile
                ? 50.0
                : 55.0;
    final cellHeight = isVerySmall
        ? 65.0
        : isSmall
            ? 70.0
            : isMobile
                ? 75.0
                : 80.0;
    final dayFontSize = isVerySmall
        ? 12.0
        : isSmall
            ? 14.0
            : 16.0;
    final eventFontSize = isVerySmall
        ? 7.0
        : isSmall
            ? 8.0
            : isMobile
                ? 9.0
                : 10.0;

    return Container(
      margin: EdgeInsets.all(isVerySmall ? 1 : 2),
      padding: EdgeInsets.symmetric(
          vertical: isVerySmall ? 2 : 3, horizontal: isVerySmall ? 1 : 2),
      width: cellWidth,
      height: cellHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isVerySmall ? 6 : 8),
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

          // Event names
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
                                    color: Colors.black.withValues(alpha: 0.8),
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
  }

  Widget _buildAgentRow(String label, String agentIdOrName) {
    // Get agent from cache, fallback to creating a dummy agent with the provided name
    final agent = _agentCache[agentIdOrName] ?? Agent(name: agentIdOrName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              agent.name,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 6),
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

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _launchUrl(whatsappUrl);
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEventDetails(BuildContext context, dynamic event) {
    // For Option events, use a specialized dialog
    if (event is Option) {
      _showOptionDetails(context, event);
      return;
    }

    // Get event title
    String title = 'Event Details';
    if (event is Job) {
      title = event.clientName;
    } else if (event is Casting) {
      title = event.clientName ?? 'Casting';
    } else if (event is Test) {
      title = event.clientName ?? 'Test';
    } else if (event is Polaroid) {
      title = event.clientName;
    } else if (event is Meeting) {
      title = event.clientName;
    } else if (event is OnStay) {
      title = event.locationName;
    } else if (event is DirectBooking) {
      title = event.clientName;
    } else if (event is DirectOptions) {
      title = event.clientName;
    } else if (event is AiJob) {
      title = event.clientName;
    } else if (event is Event) {
      title = event.clientName ?? 'Event';
    }

    // Get event date
    DateTime? eventDate;
    if (event is Job) {
      eventDate = DateTime.tryParse(event.date);
    } else if (event is Casting) {
      eventDate = event.date;
    } else if (event is Test) {
      eventDate = event.date;
    } else if (event is AiJob) {
      eventDate = event.date;
    } else if (event is Event) {
      eventDate = event.date;
    } else if (event is DirectBooking) {
      eventDate = event.date;
    } else if (event is DirectOptions) {
      eventDate = event.date;
    } else if (event is OnStay) {
      eventDate = event.checkInDate;
    } else if (event is Meeting) {
      eventDate = DateTime.tryParse(event.date);
    } else if (event is Option) {
      eventDate = DateTime.tryParse(event.date);
    } else if (event is Polaroid) {
      eventDate = DateTime.tryParse(event.date);
    }

    // Get event location
    String? location;
    if (event is Job) {
      location = event.location;
    } else if (event is Casting) {
      location = event.location;
    } else if (event is Test) {
      location = event.location;
    } else if (event is AiJob) {
      location = event.location;
    } else if (event is Event) {
      location = event.location;
    } else if (event is DirectBooking) {
      location = event.location;
    } else if (event is DirectOptions) {
      location = event.location;
    } else if (event is OnStay) {
      location = event.address;
    } else if (event is Meeting) {
      location = event.location;
    } else if (event is Option) {
      location = event.location;
    } else if (event is Polaroid) {
      location = event.location;
    }

    // Get event time
    String? time;
    if (event is Job && event.time != null) {
      time = event.time;
    } else if (event is Casting && event.startTime != null) {
      String timeText = event.startTime!;
      if (event.endTime != null) {
        timeText += ' - ${event.endTime}';
      }
      time = timeText;
    } else if (event is AiJob && event.time != null) {
      time = event.time;
    } else if (event is Event && event.startTime != null) {
      time = event.startTime;
    } else if (event is DirectBooking && event.time != null) {
      time = event.time;
    } else if (event is DirectOptions && event.time != null) {
      time = event.time;
    } else if (event is OnStay && event.checkInTime != null) {
      time = event.checkInTime;
    } else if (event is Meeting && event.time != null) {
      time = event.time;
    } else if (event is Option && event.time != null) {
      time = event.time;
    } else if (event is Polaroid && event.time != null) {
      time = event.time;
    }
    // Note: Test events don't have time fields

    // Get event rate
    double? rate;
    String? currency;
    if (event is Job) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is Casting) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is Test) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is AiJob) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is Event) {
      rate = event.dayRate;
      currency = event.currency;
    } else if (event is DirectBooking) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is DirectOptions) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is OnStay) {
      rate = event.cost;
      currency = event.currency;
    } else if (event is Option) {
      rate = event.rate;
      currency = event.currency;
    } else if (event is Polaroid) {
      rate = event.rate;
      currency = event.currency;
    }
    // Note: Meeting events don't have rate fields

    // Get event notes/description
    String? notes;
    if (event is Job) {
      notes = event.notes;
    } else if (event is Casting) {
      notes = event.description; // Casting uses 'description' field
    } else if (event is Test) {
      notes = event.description; // Test uses 'description' field
    } else if (event is AiJob) {
      notes = event.notes;
    } else if (event is Event) {
      notes = event.notes;
    } else if (event is DirectBooking) {
      notes = event.notes;
    } else if (event is DirectOptions) {
      notes = event.notes;
    } else if (event is OnStay) {
      notes = _getCleanNotesFromOnStay(event.notes);
    } else if (event is Meeting) {
      notes = event.notes;
    } else if (event is Option) {
      notes = event.notes;
    } else if (event is Polaroid) {
      notes = event.notes;
    }

    // Get agent information
    String? agentId;
    if (event is Job) {
      agentId = event.bookingAgent;
    } else if (event is Casting) {
      agentId = event.agentId;
    } else if (event is Test) {
      agentId = event.agentId;
    } else if (event is AiJob) {
      agentId = event.bookingAgent;
    } else if (event is OnStay) {
      agentId = event.agentId;
      // Fallback: try to extract agent ID from notes if agentId is empty
      if ((agentId == null || agentId.isEmpty) && event.notes != null) {
        agentId = _getAgentIdFromOnStayNotes(event.notes!);
      }
    } else if (event is Meeting) {
      agentId = event.bookingAgent;
    } else if (event is Option) {
      agentId = event.agentId;
    } else if (event is DirectBooking) {
      agentId = event.bookingAgent;
    } else if (event is DirectOptions) {
      agentId = event.bookingAgent;
    } else if (event is Polaroid) {
      agentId = event.bookingAgent;
    } else if (event is Event) {
      agentId = event.agentId;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildEventDetailsContent(event, eventDate, location,
                  time, rate, currency, notes, agentId),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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

  List<Widget> _buildEventDetailsContent(
      dynamic event,
      DateTime? eventDate,
      String? location,
      String? time,
      double? rate,
      String? currency,
      String? notes,
      String? agentId) {
    List<Widget> details = [];

    // Type
    details.addAll([
      _buildDetailRow('Type', _getEventType(event)),
      const SizedBox(height: 8),
    ]);

    // Date
    details.addAll([
      _buildDetailRow(
          'Date',
          eventDate != null
              ? DateFormat('EEEE, MMMM d, yyyy').format(eventDate)
              : 'Date not specified'),
      const SizedBox(height: 8),
    ]);

    // Time
    if (time != null) {
      details.addAll([
        _buildDetailRow('Time', time),
        const SizedBox(height: 8),
      ]);
    }

    // Location
    details.addAll([
      _buildDetailRow(
          'Location',
          location != null && location.isNotEmpty
              ? location
              : 'No location specified'),
      const SizedBox(height: 8),
    ]);

    // Rate
    if (rate != null && rate > 0) {
      details.addAll([
        _buildDetailRow(
            'Day Rate', '${currency ?? 'USD'} ${rate.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Agent
    if (agentId != null && agentId.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', agentId),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    String? status = _getEventStatus(event);
    if (status != null) {
      details.addAll([
        _buildDetailRow('Status', status),
        const SizedBox(height: 8),
      ]);
    }

    // Payment Status
    String? paymentStatus = _getEventPaymentStatus(event);
    if (paymentStatus != null) {
      details.addAll([
        _buildDetailRow('Payment', paymentStatus),
        const SizedBox(height: 8),
      ]);
    }

    // Notes (at the bottom)
    if (notes != null && notes.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', notes),
      ]);
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
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String? _getEventStatus(dynamic event) {
    if (event is Job) return event.status?.toUpperCase();
    if (event is DirectBooking) return event.status?.toUpperCase();
    if (event is DirectOptions) return event.status?.toUpperCase();
    if (event is OnStay) return event.status.toUpperCase();
    if (event is Option) return event.status.toUpperCase();
    if (event is AiJob) return event.status?.toUpperCase();
    if (event is Event) {
      return event.status?.toString().split('.').last.toUpperCase();
    }
    return null;
  }

  String? _getEventPaymentStatus(dynamic event) {
    if (event is Job) return event.paymentStatus?.toUpperCase();
    if (event is DirectBooking) return event.paymentStatus?.toUpperCase();
    if (event is DirectOptions) return event.paymentStatus?.toUpperCase();
    if (event is OnStay) return event.paymentStatus.toUpperCase();
    if (event is Option) return event.paymentStatus.toUpperCase();
    if (event is AiJob) return event.paymentStatus?.toUpperCase();
    if (event is Event) {
      return event.paymentStatus?.toString().split('.').last.toUpperCase();
    }
    return null;
  }

  void _showOptionDetails(BuildContext context, Option option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          option.clientName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildOptionDetails(option),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditEvent(option);
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

  List<Widget> _buildOptionDetails(Option option) {
    List<Widget> details = [];

    // Type
    details.addAll([
      _buildDetailRow('Type', 'Option'),
      const SizedBox(height: 8),
    ]);

    // Date
    try {
      final date = DateTime.parse(option.date);
      details.addAll([
        _buildDetailRow('Date', DateFormat('EEEE, MMMM d, yyyy').format(date)),
        const SizedBox(height: 8),
      ]);
    } catch (e) {
      details.addAll([
        _buildDetailRow('Date', option.date),
        const SizedBox(height: 8),
      ]);
    }

    // Time
    if (option.time != null) {
      String timeText = option.time!;
      if (option.endTime != null) {
        timeText += ' - ${option.endTime}';
      }
      details.addAll([
        _buildDetailRow('Time', timeText),
        const SizedBox(height: 8),
      ]);
    }

    // Location
    if (option.location != null && option.location!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Location', option.location!),
        const SizedBox(height: 8),
      ]);
    }

    // Day Rate
    if (option.rate != null && option.rate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate',
            '${option.currency ?? 'USD'} ${option.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Agent
    if (option.agentId != null && option.agentId!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', option.agentId!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    details.addAll([
      _buildDetailRow('Status', option.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Payment Status
    details.addAll([
      _buildDetailRow('Payment', option.paymentStatus.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Notes (at the bottom)
    if (option.notes != null && option.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', option.notes!),
      ]);
    }

    return details;
  }

  Widget _buildEventCard(dynamic event) {
    final color = _getEventColor(event);
    final type = _getEventType(event);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showEventDetails(context, event);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _getEventTime(event),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _getEventTitle(event),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _getEventLocation(event),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_getEventDescription(event) != null) ...[
                const SizedBox(height: 8),
                Text(
                  _getEventDescription(event)!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(0),
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
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
                    cellMargin:
                        EdgeInsets.all(MediaQuery.of(context).size.width < 360
                            ? 1
                            : MediaQuery.of(context).size.width < 600
                                ? 2
                                : 3),
                    cellPadding: const EdgeInsets.all(0),
                    weekendTextStyle: const TextStyle(color: Colors.white),
                    defaultTextStyle: const TextStyle(color: Colors.white),
                    todayTextStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon:
                        Icon(Icons.chevron_left, color: Colors.white),
                    rightChevronIcon:
                        Icon(Icons.chevron_right, color: Colors.white),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Colors.white70),
                    weekendStyle: TextStyle(color: Colors.white70),
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
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(),
              ),
              SizedBox(
                height:
                    constraints.maxHeight * 0.5, // Use half of available height
                child: ListView(
                  padding: const EdgeInsets.all(0),
                  children: [
                    if (_selectedDay != null) ...[
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(_selectedDay!),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._getEventsForDay(
                        _selectedDay!,
                      ).map((event) => _buildEventCard(event)),
                      if (_getEventsForDay(_selectedDay!).isEmpty)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 32),
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No events for this day',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgendaView() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('This Week', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 7; i++) ...[
          _buildDayEvents(startOfWeek.add(Duration(days: i))),
          if (i < 6) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDayEvents(DateTime day) {
    final events = _getEventsForDay(day);
    final isToday = isSameDay(day, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isToday ? AppTheme.goldColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                DateFormat('E, MMM d').format(day),
                style: TextStyle(
                  color: isToday ? Colors.black : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...events.map((event) => _buildEventCard(event)),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No events',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📅 CalendarPage.build() - Building calendar page...');
    return AppLayout(
      currentPage: '/calendar',
      title: 'Calendar',
      actions: [
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Today'),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            Navigator.pushNamed(context, '/new-option');
          },
          tooltip: 'Add Option',
        ),
        IconButton(
          icon: Icon(
            _viewMode == 'month' ? Icons.view_agenda : Icons.calendar_month,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _viewMode = _viewMode == 'month' ? 'agenda' : 'month';
            });
          },
          tooltip: 'Toggle View',
        ),
      ],
      child: _buildSafeContent(),
    );
  }

  Widget _buildSafeContent() {
    try {
      // Early return for disposed state to prevent white screens
      if (_isDisposed) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      if (_isLoading) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading calendar events...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }

      if (_error != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEvents,
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }

      return _viewMode == 'month' ? _buildCalendarView() : _buildAgendaView();
    } catch (e) {
      debugPrint('❌ Error in calendar build: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Something went wrong with the calendar.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (!_isDisposed) {
                  setState(() {
                    _error = null;
                    _isLoading = false;
                  });
                  _loadEvents();
                }
              },
              child: Text('Restart Calendar'),
            ),
          ],
        ),
      );
    }
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

  /// Extract agent ID from OnStay notes field as fallback
  String? _getAgentIdFromOnStayNotes(String notes) {
    if (notes.isEmpty) return null;

    final lines = notes.split('\n');

    // First, try to find explicit Agent ID
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('Agent ID: ')) {
        return line.substring('Agent ID: '.length);
      }
    }

    // Fallback: try to match agency name against agent names
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('Agency: ')) {
        final agencyName = line.substring('Agency: '.length).trim();
        if (agencyName.isNotEmpty) {
          // Try to find an agent with matching name
          for (final agent in _agentCache.values) {
            if (agent.name.toLowerCase() == agencyName.toLowerCase()) {
              return agent.id;
            }
          }
        }
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
}
