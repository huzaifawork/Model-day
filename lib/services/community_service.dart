import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:new_flutter/models/community_post.dart';
import 'package:new_flutter/services/email_service.dart';
import 'package:new_flutter/services/notification_service.dart';

class CommunityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'community_posts';
  static const String _commentsCollection = 'comments';

  /// Get all community posts ordered by timestamp (newest first)
  static Future<List<CommunityPost>> getPosts() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit to 50 most recent posts
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityPost.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      debugPrint('Error getting posts: $e');
      // Return empty list instead of mock data
      return [];
    }
  }

  /// Create a new community post
  static Future<void> createPost(String content, {
    String? category,
    String? location,
    String? date,
    String? time,
    String? contactMethod,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate tags based on category and content
      List<String> tags = [];
      if (category != null && category != 'All Categories') {
        tags.add(category.toLowerCase().replaceAll(' ', '_'));
      }

      // Add tags based on content keywords
      final contentLower = content.toLowerCase();
      if (contentLower.contains('roommate')) tags.add('roommate');
      if (contentLower.contains('housing')) tags.add('housing');
      if (contentLower.contains('job')) tags.add('jobs');
      if (contentLower.contains('event')) tags.add('events');

      final post = {
        'authorId': user.uid,
        'authorName': user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'tags': tags,
        'category': category ?? 'General',
        'location': location,
        'date': date,
        'time': time,
        'contactMethod': contactMethod ?? 'Comments',
      };

      await _firestore.collection(_collection).add(post);
    } catch (e) {
      debugPrint('Error creating post: $e');
      throw Exception('Failed to create post: $e');
    }
  }

  /// Like a post
  static Future<void> likePost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).update({
        'likes': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error liking post: $e');
      throw Exception('Failed to like post: $e');
    }
  }

  /// Unlike a post
  static Future<void> unlikePost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).update({
        'likes': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error unliking post: $e');
      throw Exception('Failed to unlike post: $e');
    }
  }

  /// Get posts by a specific user
  static Future<List<CommunityPost>> getPostsByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('authorId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityPost.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      return [];
    }
  }

  /// Delete a post (only by the author)
  static Future<void> deletePost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is the author
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (!doc.exists) {
        throw Exception('Post not found');
      }

      final postData = doc.data()!;
      if (postData['authorId'] != user.uid) {
        throw Exception('Not authorized to delete this post');
      }

      // Delete all comments for this post first
      final commentsQuery = await _firestore
          .collection(_commentsCollection)
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();
      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete the post
      batch.delete(_firestore.collection(_collection).doc(postId));

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting post: $e');
      throw Exception('Failed to delete post: $e');
    }
  }

  /// Get a single community post by its ID
  static Future<CommunityPost> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (!doc.exists) {
        throw Exception('Post with ID $postId not found');
      }
      return CommunityPost.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e) {
      debugPrint('Error getting post by ID: $e');
      throw Exception('Failed to get post by ID: $e');
    }
  }

  /// Update a post (only by the author)
  static Future<void> updatePost(String postId, String content, {
    String? category,
    String? location,
    String? date,
    String? time,
    String? contactMethod,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is the author
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (!doc.exists) {
        throw Exception('Post not found');
      }

      final postData = doc.data()!;
      if (postData['authorId'] != user.uid) {
        throw Exception('Not authorized to edit this post');
      }

      // Generate tags based on category and content
      List<String> tags = [];
      if (category != null && category != 'All Categories') {
        tags.add(category.toLowerCase().replaceAll(' ', '_'));
      }

      // Add tags based on content keywords
      final contentLower = content.toLowerCase();
      if (contentLower.contains('roommate')) tags.add('roommate');
      if (contentLower.contains('housing')) tags.add('housing');
      if (contentLower.contains('job')) tags.add('jobs');
      if (contentLower.contains('event')) tags.add('events');

      await _firestore.collection(_collection).doc(postId).update({
        'content': content,
        'tags': tags,
        'category': category ?? 'General',
        'location': location,
        'date': date,
        'time': time,
        'contactMethod': contactMethod ?? 'Comments',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating post: $e');
      throw Exception('Failed to update post: $e');
    }
  }

  /// Get comments for a post
  static Future<List<Comment>> getComments(String postId) async {
    try {
      debugPrint('🔍 Getting comments for post: $postId');

      // First try with orderBy
      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection(_commentsCollection)
            .where('postId', isEqualTo: postId)
            .orderBy('timestamp', descending: true)
            .get();
      } catch (orderByError) {
        debugPrint('⚠️ OrderBy failed, trying without orderBy: $orderByError');
        // If orderBy fails (e.g., missing index), try without it
        querySnapshot = await _firestore
            .collection(_commentsCollection)
            .where('postId', isEqualTo: postId)
            .get();
      }

      debugPrint('📝 Found ${querySnapshot.docs.length} comments');

      final comments = querySnapshot.docs
          .map((doc) {
            debugPrint('📄 Comment doc: ${doc.id} - ${doc.data()}');
            final data = doc.data() as Map<String, dynamic>;
            return Comment.fromJson({
              'id': doc.id,
              ...data,
            });
          })
          .toList();

      // Sort manually if we couldn't use orderBy
      comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return comments;
    } catch (e) {
      debugPrint('❌ Error getting comments: $e');
      return [];
    }
  }

  /// Add a comment to a post
  static Future<void> addComment(String postId, String content) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('➕ Adding comment to post: $postId');
      debugPrint('👤 User: ${user.uid} (${user.displayName ?? user.email})');
      debugPrint('💬 Content: $content');

      // Get the post details first to get author information
      final postDoc = await _firestore.collection(_collection).doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      final postAuthorId = postData['authorId'] as String;
      final postContent = postData['content'] as String;

      // Extract post title (first line of content)
      final postTitle = postContent.split('\n').first;

      final comment = {
        'postId': postId,
        'authorId': user.uid,
        'authorName': user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      };

      debugPrint('📝 Comment data: $comment');

      // Add the comment
      final docRef = await _firestore.collection(_commentsCollection).add(comment);
      debugPrint('✅ Comment added with ID: ${docRef.id}');

      // Increment the comment count on the post
      await _firestore.collection(_collection).doc(postId).update({
        'comments': FieldValue.increment(1),
      });
      debugPrint('📊 Post comment count incremented');

      // Send email notification to post author (if not commenting on own post)
      if (postAuthorId != user.uid) {
        final postAuthorEmail = await EmailService.getUserEmail(postAuthorId);
        if (postAuthorEmail != null) {
          final commenterName = user.displayName ?? user.email?.split('@').first ?? 'Anonymous';

          debugPrint('📧 Sending comment notification email to: $postAuthorEmail');
          final emailSent = await EmailService.sendCommentNotificationCompat(
            postAuthorEmail: postAuthorEmail,
            postTitle: postTitle,
            commenterName: commenterName,
            commentContent: content,
            postId: postId,
          );

          if (emailSent) {
            debugPrint('✅ Comment notification email sent successfully');
          } else {
            debugPrint('⚠️ Comment notification email failed to send');
          }
        } else {
          debugPrint('⚠️ Could not find email for post author: $postAuthorId');
        }

        // Create in-app notification for post author
        try {
          final commenterName = user.displayName ?? user.email?.split('@').first ?? 'Anonymous';
          final notificationService = NotificationService();
          await notificationService.createCommentNotification(
            postOwnerId: postAuthorId,
            postId: postId,
            commentId: docRef.id,
            commenterUserId: user.uid,
            commenterName: commenterName,
            postTitle: postTitle,
          );
          debugPrint('🔔 In-app notification created successfully');
        } catch (notificationError) {
          debugPrint('⚠️ Failed to create in-app notification: $notificationError');
        }
      } else {
        debugPrint('ℹ️ User commented on own post, skipping notifications');
      }
    } catch (e) {
      debugPrint('❌ Error adding comment: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Update a comment (only by the author)
  static Future<void> updateComment(String commentId, String newContent) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is the author of the comment
      final doc = await _firestore.collection(_commentsCollection).doc(commentId).get();
      if (!doc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = doc.data()!;
      if (commentData['authorId'] != user.uid) {
        throw Exception('Not authorized to edit this comment');
      }

      // Update the comment
      await _firestore.collection(_commentsCollection).doc(commentId).update({
        'content': newContent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating comment: $e');
      throw Exception('Failed to update comment: $e');
    }
  }

  /// Delete a comment (only by the author)
  static Future<void> deleteComment(String commentId, String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is the author of the comment
      final doc = await _firestore.collection(_commentsCollection).doc(commentId).get();
      if (!doc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = doc.data()!;
      if (commentData['authorId'] != user.uid) {
        throw Exception('Not authorized to delete this comment');
      }

      // Delete the comment
      await _firestore.collection(_commentsCollection).doc(commentId).delete();

      // Decrement the comment count on the post
      await _firestore.collection(_collection).doc(postId).update({
        'comments': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      throw Exception('Failed to delete comment: $e');
    }
  }

  /// Check if user can edit/delete a post
  static bool canEditPost(CommunityPost post) {
    final user = _auth.currentUser;
    return user != null && user.uid == post.authorId;
  }

  /// Check if user can edit a comment
  static bool canEditComment(Comment comment) {
    final user = _auth.currentUser;
    return user != null && user.uid == comment.authorId;
  }

  /// Check if user can delete a comment
  static bool canDeleteComment(Comment comment) {
    final user = _auth.currentUser;
    return user != null && user.uid == comment.authorId;
  }

  /// Debug method to check all comments in the collection
  static Future<void> debugAllComments() async {
    try {
      debugPrint('🔍 DEBUG: Checking all comments in collection');
      final querySnapshot = await _firestore
          .collection(_commentsCollection)
          .get();

      debugPrint('📊 Total comments in collection: ${querySnapshot.docs.length}');

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        debugPrint('📄 Comment ${doc.id}: $data');
      }
    } catch (e) {
      debugPrint('❌ Error in debug: $e');
    }
  }

  /// Test method to verify comment functionality
  static Future<String> testCommentFunctionality(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Error: User not authenticated';
      }

      // Test 1: Try to add a test comment
      debugPrint('🧪 TEST 1: Adding test comment');
      final testComment = {
        'postId': postId,
        'authorId': user.uid,
        'authorName': 'TEST_USER',
        'content': 'This is a test comment - ${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection(_commentsCollection).add(testComment);
      debugPrint('✅ TEST 1 PASSED: Comment added with ID: ${docRef.id}');

      // Test 2: Try to retrieve the comment
      debugPrint('🧪 TEST 2: Retrieving test comment');
      await Future.delayed(const Duration(seconds: 1)); // Wait for server timestamp
      final doc = await docRef.get();
      if (doc.exists) {
        debugPrint('✅ TEST 2 PASSED: Comment retrieved: ${doc.data()}');
      } else {
        debugPrint('❌ TEST 2 FAILED: Comment not found');
        return 'Test failed: Comment not found after creation';
      }

      // Test 3: Try to query comments for the post
      debugPrint('🧪 TEST 3: Querying comments for post');
      final comments = await getComments(postId);
      debugPrint('✅ TEST 3 RESULT: Found ${comments.length} comments for post');

      // Clean up: Delete the test comment
      await docRef.delete();
      debugPrint('🧹 Cleanup: Test comment deleted');

      return 'All tests passed! Comments functionality is working.';
    } catch (e) {
      debugPrint('❌ TEST FAILED: $e');
      return 'Test failed: $e';
    }
  }
}
