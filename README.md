# English Partner

English Partner is an iOS application designed to help users improve everyday English communication and pronunciation through AI-assisted practice.

## Project Overview

The application provides two main learning modes:

### 1. AI English Partner

Users can have an English conversation with an AI partner.

Features:
- Natural English conversation
- Everyday communication practice
- Gentle grammar correction
- More natural sentence suggestions
- Conversation history during the current app session
- AI-generated responses using the Gemini API

### 2. Pronunciation Practice

Users can practice pronunciation at three difficulty levels:

- Low
- Medium
- High

The app:
1. Presents a word or sentence.
2. Reads the target aloud using Apple's speech synthesis.
3. Records the user's pronunciation.
4. Sends the recorded audio to Gemini for analysis.
5. Displays a pronunciation score and feedback.
6. Allows the user to retry or continue to the next question.

## Technologies Used

- Swift
- SwiftUI
- Xcode
- AVFoundation
- AVAudioRecorder
- AVSpeechSynthesizer
- Gemini API
- JSON / REST API
- iOS Simulator

## Key Features

- Modern SwiftUI interface
- AI-powered English conversation
- AI-powered pronunciation evaluation
- Three pronunciation difficulty levels
- Audio recording
- Text-to-speech
- Pronunciation score
- AI feedback
- Retry functionality
- Next-question flow
- Temporary in-session conversation state

## Project Structure

The main implementation is contained in:

`ContentView.swift`

The application includes:
- Main tab navigation
- Chat interface
- Chat view model
- Pronunciation practice interface
- Question bank
- Audio recorder
- Speech player
- Gemini API service
- AI response models
- Error handling



## How to Run

1. Open the project in Xcode.
2. Select an iPhone Simulator.
3. Add a valid Gemini API key to the local configuration.
4. Ensure microphone permission is configured in the app's Info settings.
5. Build and run the application.
6. Open **Partner** to practice conversation.
7. Open **Practice** to practice pronunciation.

## Project Demonstration

A demonstration video is provided separately through the project submission form.

The demonstration shows:
- AI English conversation
- Navigation between Partner and Practice
- Pronunciation practice
- Audio recording
- AI pronunciation evaluation

## Purpose

The goal of English Partner is to make English communication practice more interactive and accessible by combining conversational AI, speech technology, and pronunciation feedback in one mobile application.

## Author

Kanikashree
