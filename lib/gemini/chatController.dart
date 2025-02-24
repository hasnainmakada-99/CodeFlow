import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codeflow/screens/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});

class ChatController extends StateNotifier<ChatState> {
  ChatController(this.ref) : super(ChatState()) {
    _initializeModel();
  }

  FirebaseAuth get auth => FirebaseAuth.instance;
  final Ref ref;
  late final GenerativeModel model;
  final uuid = const Uuid();

  void _initializeModel() {
    final apiKey = dotenv.env['GEMINI_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in environment variables');
    }

    model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'AIzaSyAjCoFm0FFk0zOth-91_KPcjCxFRNeHL2I',
    );
  }

  Future<void> fromText(String query) async {
    state = state.copyWith(loading: true);
    query = query.trim(); // Ignore leading and trailing whitespaces
    final content = [Content.text(query)];

    try {
      final timestamp = DateTime.now();

      // Store user's query
      final userDocRef =
          await FirebaseFirestore.instance.collection('chats').add({
        'user': auth.currentUser!.email!,
        'role': 'You',
        'text': query,
        'timestamp': timestamp,
      });

      // Generate response using Gemini
      final response = await model.generateContent(content);

      // Store Gemini response
      await FirebaseFirestore.instance.collection('chats').add({
        'user': auth.currentUser!.email!,
        'role': 'Gemini',
        'timestamp': timestamp,
        'text': response.text,
        'parent': userDocRef,
      });

      state = state.copyWith(loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }
}

class ChatState {
  final bool loading;
  final String? error;

  ChatState({
    this.loading = false,
    this.error,
  });

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  ChatState copyWith({
    bool? loading,
    String? error,
  }) {
    return ChatState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}
