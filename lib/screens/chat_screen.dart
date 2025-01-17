// Import required packages
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_fonts/google_fonts.dart';

const apiKey = "AIzaSyA6bT6-9ZwIw_k10imdMlyGXRzsTJhpPbk";

// State providers for chat data and loading state
final chatProvider = StateProvider<List<Map<String, String>>>((ref) => []);
final loadingProvider = StateProvider<bool>((ref) => false);

class ChatScreen1 extends ConsumerStatefulWidget {
  final String userEmail;

  ChatScreen1({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ChatScreen1State createState() => _ChatScreen1State();
}

class _ChatScreen1State extends ConsumerState<ChatScreen1> {
  final textController = TextEditingController();
  final model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: "AIzaSyDWqKcLnhhPNkk4--406LDodV6jpkIlU2A",
  );

  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPreviousChats();
  }

  Future<void> _loadPreviousChats() async {
    final chatListNotifier = ref.read(chatProvider.notifier);

    try {
      // Fetch messages for the specific email and order them by timestamp
      final snapshot = await FirebaseFirestore.instance
          .collection('chatMessages')
          .where('email', isEqualTo: widget.userEmail)
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final chats = snapshot.docs.map((doc) {
          final data = doc.data();
          // Ensure data contains required fields and convert values to String
          return {
            'email': data['email']?.toString() ?? '',
            'role': data['role']?.toString() ?? 'Unknown',
            'text': data['text']?.toString() ?? '',
            'timestamp': data['timestamp']?.toString() ?? '',
          };
        }).toList();

        chatListNotifier.state = List<Map<String, String>>.from(chats);
      } else {
        chatListNotifier.state = [];
      }
    } catch (e) {
      // Log error for debugging
      log('Error loading previous chats: $e');
      chatListNotifier.state = [];
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void fromText({required String query}) async {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message to send'),
        ),
      );
      return;
    }

    final content = [Content.text(query)];
    final chatListNotifier = ref.read(chatProvider.notifier);
    ref.read(loadingProvider.notifier).state = true;

    final userMessage = {
      'email': widget.userEmail,
      'role': 'You',
      'text': query,
      'timestamp': DateTime.now().toIso8601String(),
    };
    chatListNotifier.state = [...chatListNotifier.state, userMessage];
    textController.clear();

    try {
      final response = await model.generateContent(content);
      final aiMessage = {
        'email': widget.userEmail,
        'role': 'Gemini',
        'text': response.text ?? 'No response',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add both user and AI messages to Firebase
      await addToFirebase(userMessage);
      await addToFirebase(aiMessage);

      chatListNotifier.state = [...chatListNotifier.state, aiMessage];
    } catch (error) {
      final errorMessage = {
        'email': widget.userEmail,
        'role': 'Error',
        'text': 'An error occurred: $error',
        'timestamp': DateTime.now().toIso8601String(),
      };
      chatListNotifier.state = [...chatListNotifier.state, errorMessage];
    } finally {
      ref.read(loadingProvider.notifier).state = false;
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatList = ref.watch(chatProvider);
    final isLoading = ref.watch(loadingProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: chatList.isEmpty
                ? Center(
                    child: Text(
                      'No chats to display',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _controller,
                    itemCount: chatList.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final message = chatList[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color.fromARGB(255, 73, 73, 73),
                          child: Text(
                            message['role']!.substring(0, 1),
                            style: GoogleFonts.poppins(
                                color:
                                    const Color.fromARGB(255, 255, 255, 255)),
                          ),
                        ),
                        title: Text(
                          message['role']!,
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        subtitle: Text(
                          message['text']!,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: Colors.black),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    style: GoogleFonts.poppins(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Type a message",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                IconButton(
                  icon: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Icon(Icons.send, color: Colors.black),
                  onPressed: () => fromText(query: textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> addToFirebase(Map<String, String> message) async {
  final messagesRef = FirebaseFirestore.instance.collection('chatMessages');
  await messagesRef.add(message);
}
