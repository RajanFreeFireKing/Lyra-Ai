import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/api_config.dart';
import '../core/network/agent_planner_client.dart';
import '../data/models/agent_action.dart';
import 'native_channel.dart';

class ScreenAgentController extends ChangeNotifier {
  String openRouterApiKey;
  bool isExecuting = false;
  int currentStep = 0;
  String currentActionThought = "";
  AgentPlannerClient? _plannerClient;

  ScreenAgentController({
    required this.openRouterApiKey,
  }) {
    _plannerClient = AgentPlannerClient(apiKey: openRouterApiKey);
  }

  void updateApiKey(String newKey) {
    openRouterApiKey = newKey;
    _plannerClient = AgentPlannerClient(apiKey: openRouterApiKey);
    notifyListeners();
  }

  /// Exact replica of Stonic runner.py _loop
  Future<String> executeScreenTask(String taskInstruction, {int maxSteps = 25}) async {
    if (isExecuting) return "Another task is already in progress.";
    isExecuting = true;
    currentStep = 0;
    notifyListeners();

    await NativeChannel.showOverlay();
    await NativeChannel.updateOverlay("Working", "Starting: $taskInstruction");

    String previousReflection = "";

    try {
      for (int step = 1; step <= maxSteps; step++) {
        currentStep = step;
        notifyListeners();

        // 1. Capture screen
        final capture = await NativeChannel.captureScreen();
        if (capture == null || capture['png'] == null) {
          await NativeChannel.updateOverlay("Error", "Screenshot capture failed");
          return "I could not capture your screen. Please ensure screen capture permission is granted.";
        }

        final Uint8List pngBytes = capture['png'] as Uint8List;
        final int screenWidth = capture['width'] as int;
        final int screenHeight = capture['height'] as int;

        // Calculate scaled dimensions (capped at 1920)
        final maxDim = 1920;
        final maxVal = screenWidth > screenHeight ? screenWidth : screenHeight;
        final scale = maxVal <= maxDim ? 1.0 : (maxDim / maxVal.toDouble());
        final scaledW = (screenWidth * scale).round();
        final scaledH = (screenHeight * scale).round();

        // 2. Predict next action using Planner
        await NativeChannel.updateOverlay("Working", "Step $step/$maxSteps: Planning...");
        final action = await _plannerClient!.predictNextAction(
          task: taskInstruction,
          screenshotPng: pngBytes,
          stepNumber: step,
          maxSteps: maxSteps,
          previousReflection: previousReflection,
        );

        currentActionThought = action.thought;
        notifyListeners();
        await NativeChannel.updateOverlay("Step $step/$maxSteps", action.thought);

        if (action.type == ActionType.done) {
          await NativeChannel.updateOverlay("Done", "Task completed");
          return "Task completed successfully in $step steps.";
        }
        if (action.type == ActionType.fail) {
          await NativeChannel.updateOverlay("Stopped", "Unable to complete");
          return "I could not complete this task from the current screen.";
        }

        // 3. Execute Action
        if (action.type == ActionType.click) {
          // Ground element coordinates using UI-TARS
          final coords = await _plannerClient!.groundElementCoordinates(
            elementDescription: action.elementDescription,
            screenshotPng: pngBytes,
          );

          if (coords != null && coords.length >= 2) {
            // UI-TARS returns coordinates normalized to [0..1000]
            final normX = coords[0];
            final normY = coords[1];
            final targetX = (normX / 1000.0 * screenWidth).round();
            final targetY = (normY / 1000.0 * screenHeight).round();

            await NativeChannel.performClick(targetX, targetY);
            previousReflection = "Clicked on '${action.elementDescription}' at ($targetX, $targetY).";
          } else {
            // Center fallback
            await NativeChannel.performClick(screenWidth ~/ 2, screenHeight ~/ 2);
            previousReflection = "Attempted click near center.";
          }
        } else if (action.type == ActionType.typeText) {
          await NativeChannel.performTypeText(action.text);
          previousReflection = "Typed '${action.text}'.";
        } else if (action.type == ActionType.scroll) {
          await NativeChannel.performScroll(action.direction, screenWidth ~/ 2, screenHeight ~/ 2);
          previousReflection = "Scrolled ${action.direction}.";
        }

        // Settle UI (POST_ACTION_WAIT_S = 1.0s)
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      return "Step limit reached. The task may be incomplete.";
    } catch (e) {
      return "Task error: $e";
    } finally {
      isExecuting = false;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
      await NativeChannel.hideOverlay();
    }
  }
}
