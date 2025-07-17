import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/job.dart';
import '../models/casting.dart';
import '../pages/splash_page.dart';
import '../pages/landing_page.dart';
import '../pages/sign_in_page.dart';
import '../pages/sign_up_page.dart';
import '../pages/welcome_page.dart';
import '../pages/calendar_page.dart';
import '../pages/all_activities_page.dart';
import '../pages/enhanced_direct_bookings_page.dart';
import '../pages/direct_options_page.dart';
import '../pages/options_list_page.dart';
import '../pages/jobs_page_simple.dart';
import '../pages/castings_page.dart';
import '../pages/tests_page.dart';
import '../pages/on_stay_page.dart';
import '../pages/shootings_page.dart';
import '../pages/polaroids_page.dart';

import '../pages/meetings_page.dart';
import '../pages/ai_jobs_page.dart';
import '../pages/agencies_page.dart';
import '../pages/agents_page.dart';
import '../pages/industry_contacts_page.dart';
import '../pages/job_gallery_page.dart';
import '../pages/profile_page.dart';
import '../pages/support_page.dart';

import '../pages/new_job_page.dart';
import '../pages/new_ai_job_page.dart';
import '../pages/new_job_gallery_page.dart';
import '../pages/forgot_password_page.dart';
import '../pages/register_page.dart';
import '../pages/oauth_callback_page.dart';
import '../pages/oauth_test_page.dart';
import '../pages/add_event_page.dart';
import '../pages/new_agency_page.dart';
import '../pages/new_agent_page.dart';
import '../pages/new_industry_contact_page.dart';
import '../pages/new_event_page.dart';
import '../pages/new_casting_page.dart';
import '../pages/other_page.dart';
import '../pages/models_page.dart';
import '../pages/new_model_page.dart';
import '../pages/community_board_page.dart';
import '../pages/ai_chat_page.dart';
import '../pages/submit_event_page.dart';
import '../pages/admin_dashboard_page.dart';
import '../pages/admin_management_page.dart';
import '../pages/admin_support_page.dart';
import '../pages/admin_recent_activity_page.dart';
import '../pages/admin_profile_page.dart';
import '../pages/new_direct_booking_page.dart';
import '../pages/edit_direct_booking_page.dart';
import '../pages/new_on_stay_page.dart';
import '../pages/new_test_page.dart';
import '../pages/new_polaroid_page.dart';
import '../pages/new_meeting_page.dart';

/// Simple route manager to handle navigation without complex state management
class SimpleRouteManager {
  static Widget getPageForRoute(String route,
      {bool isAuthenticated = false,
      bool isInitialized = true,
      bool isAdminAuthenticated = false,
      Object? arguments}) {
    debugPrint(
        '🧭 SimpleRouteManager.getPageForRoute: $route (auth: $isAuthenticated, admin: $isAdminAuthenticated, init: $isInitialized)');

    // Extract the base route without query parameters
    final baseRoute = route.split('?').first;
    debugPrint('🔍 Base route (without query params): $baseRoute');

    // If not initialized, always show splash
    if (!isInitialized) {
      debugPrint('➡️ Not initialized, showing splash');
      return const SplashPage();
    }

    // Handle specific routes
    switch (baseRoute) {
      case '/':
        // Root route - redirect based on auth status
        if (isAuthenticated) {
          // Check admin status first
          if (isAdminAuthenticated) {
            debugPrint('➡️ Root: authenticated admin → admin dashboard');
            return const AdminDashboardPage();
          } else {
            debugPrint('➡️ Root: authenticated user → welcome');
            return const WelcomePage();
          }
        } else {
          debugPrint('➡️ Root: not authenticated → landing');
          return const LandingPage();
        }

      case '/landing':
        debugPrint('➡️ Landing page');
        return const LandingPage();

      case '/signin':
        debugPrint('➡️ Sign-in page');
        return const SignInPage();

      case '/signup':
        debugPrint('➡️ Sign-up page');
        return const SignUpPage();

      case '/welcome':
        if (isAuthenticated) {
          // If admin tries to access welcome, redirect to admin dashboard
          if (isAdminAuthenticated) {
            debugPrint(
                '➡️ Admin accessing welcome → redirect to admin dashboard');
            return const AdminDashboardPage();
          } else {
            debugPrint('➡️ Welcome page (authenticated)');
            return const WelcomePage();
          }
        } else {
          debugPrint(
              '➡️ Welcome page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Calendar and Activities
      case '/calendar':
        if (isAuthenticated) {
          debugPrint('➡️ Calendar page (authenticated)');
          return const CalendarPage();
        } else {
          debugPrint(
              '➡️ Calendar page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/all-activities':
        if (isAuthenticated) {
          debugPrint('➡️ All activities page (authenticated)');
          return const AllActivitiesPage();
        } else {
          debugPrint(
              '➡️ All activities page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/community-board':
        if (isAuthenticated) {
          debugPrint('➡️ Community board page (authenticated)');
          return const CommunityBoardPage();
        } else {
          debugPrint(
              '➡️ Community board page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Job related pages
      case '/jobs':
        if (isAuthenticated) {
          debugPrint('➡️ Jobs page (authenticated)');
          return const JobsPageSimple();
        } else {
          debugPrint('➡️ Jobs page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-job':
        if (isAuthenticated) {
          debugPrint('➡️ New job page (authenticated)');
          Job? job;
          if (arguments is Job) {
            job = arguments;
          } else if (arguments is Map<String, dynamic>) {
            // Handle preselected date from calendar
            debugPrint('🔧 Route arguments (Map): $arguments');
          } else {
            debugPrint('🔧 Route arguments: $arguments');
          }
          debugPrint('🔧 Parsed job: ${job?.id} - ${job?.clientName}');
          return NewJobPage(job: job);
        } else {
          debugPrint(
              '➡️ New job page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // AI Jobs
      case '/ai-jobs':
        if (isAuthenticated) {
          debugPrint('➡️ AI jobs page (authenticated)');
          return const AiJobsPage();
        } else {
          debugPrint(
              '➡️ AI jobs page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-ai-job':
        if (isAuthenticated) {
          debugPrint('➡️ New AI job page (authenticated)');
          return const NewAiJobPage();
        } else {
          debugPrint(
              '➡️ New AI job page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Direct bookings and options
      case '/direct-bookings':
        if (isAuthenticated) {
          debugPrint('➡️ Direct bookings page (authenticated)');
          return const EnhancedDirectBookingsPage();
        } else {
          debugPrint(
              '➡️ Direct bookings page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/direct-options':
        if (isAuthenticated) {
          debugPrint('➡️ Direct options page (authenticated)');
          return const DirectOptionsPage();
        } else {
          debugPrint(
              '➡️ Direct options page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/options':
        if (isAuthenticated) {
          debugPrint('➡️ Options list page (authenticated)');
          return const OptionsListPage();
        } else {
          debugPrint(
              '➡️ Options list page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-option':
        if (isAuthenticated) {
          debugPrint('➡️ New option page (authenticated)');
          debugPrint('🔍 Route arguments: $arguments');
          debugPrint('🔍 Arguments type: ${arguments.runtimeType}');

          // Handle edit mode with arguments
          if (arguments is Map<String, dynamic>) {
            final event = arguments['event'] as Event?;
            debugPrint(
                '🔍 Extracted event: ${event?.id} - ${event?.clientName}');
            return NewEventPage(
                eventType: EventType.option, existingEvent: event);
          }
          debugPrint('ℹ️ No arguments provided, creating new option');
          return NewEventPage(eventType: EventType.option);
        } else {
          debugPrint(
              '➡️ New option page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/other':
        if (isAuthenticated) {
          debugPrint('➡️ Other events page (authenticated)');
          return const OtherPage();
        } else {
          debugPrint(
              '➡️ Other events page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Other event types
      case '/castings':
        if (isAuthenticated) {
          debugPrint('➡️ Castings page (authenticated)');
          return const CastingsPage();
        } else {
          debugPrint(
              '➡️ Castings page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/tests':
        if (isAuthenticated) {
          debugPrint('➡️ Tests page (authenticated)');
          return const TestsPage();
        } else {
          debugPrint('➡️ Tests page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/on-stay':
        if (isAuthenticated) {
          debugPrint('➡️ On stay page (authenticated)');
          return const OnStayPage();
        } else {
          debugPrint(
              '➡️ On stay page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/shootings':
        if (isAuthenticated) {
          debugPrint('➡️ Shootings page (authenticated)');
          return const ShootingsPage();
        } else {
          debugPrint(
              '➡️ Shootings page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/polaroids':
        if (isAuthenticated) {
          debugPrint('➡️ Polaroids page (authenticated)');
          return const PolaroidsPage();
        } else {
          debugPrint(
              '➡️ Polaroids page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-polaroid':
        if (isAuthenticated) {
          debugPrint('➡️ New polaroid page (authenticated)');
          return const NewPolaroidPage();
        } else {
          debugPrint(
              '➡️ New polaroid page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/meetings':
        if (isAuthenticated) {
          debugPrint('➡️ Meetings page (authenticated)');
          return const MeetingsPage();
        } else {
          debugPrint(
              '➡️ Meetings page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-meeting':
        if (isAuthenticated) {
          debugPrint('➡️ New meeting page (authenticated)');
          return const NewMeetingPage();
        } else {
          debugPrint(
              '➡️ New meeting page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-casting':
        if (isAuthenticated) {
          debugPrint('➡️ New casting page (authenticated)');
          // Handle edit mode with arguments
          if (arguments is Casting) {
            return NewCastingPage(casting: arguments);
          }
          return const NewCastingPage();
        } else {
          debugPrint(
              '➡️ New casting page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-test':
        if (isAuthenticated) {
          debugPrint('➡️ New test page (authenticated)');
          return const NewTestPage();
        } else {
          debugPrint(
              '➡️ New test page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-on-stay':
        if (isAuthenticated) {
          debugPrint('➡️ New on stay page (authenticated)');
          return const NewOnStayPage();
        } else {
          debugPrint(
              '➡️ New on stay page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-shooting':
        if (isAuthenticated) {
          debugPrint('➡️ New shooting page (authenticated)');
          return NewEventPage(eventType: EventType.polaroids);
        } else {
          debugPrint(
              '➡️ New shooting page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-direct-booking':
        if (isAuthenticated) {
          debugPrint('➡️ New direct booking page (authenticated)');
          return const NewDirectBookingPage();
        } else {
          debugPrint(
              '➡️ New direct booking page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/edit-direct-booking':
        if (isAuthenticated) {
          debugPrint('➡️ Edit direct booking page (authenticated)');
          return const EditDirectBookingPage();
        } else {
          debugPrint(
              '➡️ Edit direct booking page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-direct-option':
        if (isAuthenticated) {
          debugPrint('➡️ New direct option page (authenticated)');
          // Handle edit mode with arguments
          if (arguments is Map<String, dynamic>) {
            final event = arguments['event'] as Event?;
            return NewEventPage(
                eventType: EventType.directOption, existingEvent: event);
          }
          return NewEventPage(eventType: EventType.directOption);
        } else {
          debugPrint(
              '➡️ New direct option page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/models':
        if (isAuthenticated) {
          debugPrint('➡️ Models page (authenticated)');
          return const ModelsPage();
        } else {
          debugPrint(
              '➡️ Models page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-model':
        if (isAuthenticated) {
          debugPrint('➡️ New model page (authenticated)');
          return const NewModelPage();
        } else {
          debugPrint(
              '➡️ New model page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Management pages
      case '/agencies':
        if (isAuthenticated) {
          debugPrint('➡️ Agencies page (authenticated)');
          return const AgenciesPage();
        } else {
          debugPrint(
              '➡️ Agencies page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-agency':
        if (isAuthenticated) {
          debugPrint('➡️ New agency page (authenticated)');
          return const NewAgencyPage();
        } else {
          debugPrint(
              '➡️ New agency page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/agents':
        if (isAuthenticated) {
          debugPrint('➡️ Agents page (authenticated)');
          return const AgentsPage();
        } else {
          debugPrint(
              '➡️ Agents page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-agent':
        if (isAuthenticated) {
          debugPrint('➡️ New agent page (authenticated)');
          return const NewAgentPage();
        } else {
          debugPrint(
              '➡️ New agent page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/industry-contacts':
        if (isAuthenticated) {
          debugPrint('➡️ Industry contacts page (authenticated)');
          return const IndustryContactsPage();
        } else {
          debugPrint(
              '➡️ Industry contacts page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-industry-contact':
        if (isAuthenticated) {
          debugPrint('➡️ New industry contact page (authenticated)');
          return const NewIndustryContactPage();
        } else {
          debugPrint(
              '➡️ New industry contact page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // User pages
      case '/profile':
        if (isAuthenticated) {
          debugPrint('➡️ Profile page (authenticated)');
          return const ProfilePage();
        } else {
          debugPrint(
              '➡️ Profile page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/support':
        if (isAuthenticated) {
          debugPrint('➡️ Support page (authenticated)');
          return const SupportPage();
        } else {
          debugPrint(
              '➡️ Support page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Gallery and other features
      case '/job-gallery':
        if (isAuthenticated) {
          debugPrint('➡️ Job gallery page (authenticated)');
          return const JobGalleryPage();
        } else {
          debugPrint(
              '➡️ Job gallery page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-job-gallery':
        if (isAuthenticated) {
          debugPrint('➡️ New job gallery page (authenticated)');
          return const NewJobGalleryPage();
        } else {
          debugPrint(
              '➡️ New job gallery page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/ai-chat':
        if (isAuthenticated) {
          debugPrint('➡️ AI chat page (authenticated)');
          return const AIChatPage();
        } else {
          debugPrint(
              '➡️ AI chat page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/submit-event':
        if (isAuthenticated) {
          debugPrint('➡️ Submit event page (authenticated)');
          return const SubmitEventPage();
        } else {
          debugPrint(
              '➡️ Submit event page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Auth pages
      case '/forgot-password':
        debugPrint('➡️ Forgot password page');
        return const ForgotPasswordPage();

      case '/register':
        debugPrint('➡️ Register page');
        return const RegisterPage();

      case '/auth/callback':
        debugPrint('➡️ OAuth callback page');
        return const OAuthCallbackPage();

      case '/__/auth/handler':
        debugPrint('➡️ Firebase OAuth callback page');
        return const OAuthCallbackPage();

      case '/oauth-test':
        debugPrint('➡️ OAuth test page');
        return const OAuthTestPage();

      // Event creation pages
      case '/add-event':
        if (isAuthenticated) {
          debugPrint('➡️ Add event page (authenticated)');
          return const AddEventPage();
        } else {
          debugPrint(
              '➡️ Add event page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/new-event':
        if (isAuthenticated) {
          debugPrint('➡️ New event page (authenticated)');
          // Handle edit mode with arguments
          if (arguments is Map<String, dynamic>) {
            final eventType =
                arguments['eventType'] as EventType? ?? EventType.other;
            final event = arguments['event'] as Event?;
            return NewEventPage(eventType: eventType, existingEvent: event);
          }
          return NewEventPage(eventType: EventType.other);
        } else {
          debugPrint(
              '➡️ New event page requested but not authenticated → sign-in');
          return const SignInPage();
        }

      // Admin routes - require authentication and admin access
      case '/admin/dashboard':
        if (isAuthenticated) {
          debugPrint('➡️ Admin dashboard page');
          return const AdminDashboardPage();
        } else {
          debugPrint(
              '➡️ Admin dashboard requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/admin/users':
        if (isAuthenticated) {
          debugPrint('➡️ Admin user management page');
          return const AdminManagementPage();
        } else {
          debugPrint(
              '➡️ Admin user management requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/admin/activity':
        if (isAuthenticated) {
          debugPrint('➡️ Admin recent activity page');
          return const AdminRecentActivityPage();
        } else {
          debugPrint(
              '➡️ Admin recent activity requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/admin/profile':
        if (isAuthenticated) {
          debugPrint('➡️ Admin profile page');
          return const AdminProfilePage();
        } else {
          debugPrint(
              '➡️ Admin profile requested but not authenticated → sign-in');
          return const SignInPage();
        }

      case '/admin/support':
        if (isAuthenticated) {
          debugPrint('➡️ Admin support page');
          return const AdminSupportPage();
        } else {
          debugPrint(
              '➡️ Admin support requested but not authenticated → sign-in');
          return const SignInPage();
        }

      default:
        // For any other route, check authentication
        if (isAuthenticated) {
          debugPrint('➡️ Unknown route: $baseRoute (authenticated) → welcome');
          return const WelcomePage();
        } else {
          debugPrint(
              '➡️ Unknown route: $baseRoute (not authenticated) → sign-in');
          return const SignInPage();
        }
    }
  }

  /// Check if a route is public (doesn't require authentication)
  static bool isPublicRoute(String route) {
    const publicRoutes = [
      '/',
      '/landing',
      '/signin',
      '/signup',
      '/forgot-password',
      '/register',
    ];
    return publicRoutes.contains(route);
  }

  /// Get the appropriate route based on auth status
  static String getDefaultRoute(
      {bool isAuthenticated = false, bool isAdminAuthenticated = false}) {
    if (isAuthenticated) {
      // Check if user is admin
      if (isAdminAuthenticated) {
        return '/admin/dashboard';
      }
      return '/welcome';
    } else {
      return '/landing';
    }
  }
}
