import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../../data/models/agent_action.dart';

class AgentPlannerClient {
  final String apiKey;
  final String plannerModel;
  final String groundingModel;
  final String baseUrl;

  AgentPlannerClient({
    required this.apiKey,
    this.plannerModel = ApiConfig.defaultPlannerModel,
    this.groundingModel = ApiConfig.defaultGroundingModel,
    this.baseUrl = ApiConfig.openRouterBaseUrl,
  });

  /// Step 1: Planner LLM analyzes screenshot and outputs high-level action code
  Future<AgentAction> predictNextAction({
    required String task,
    required Uint8List screenshotPng,
    required int stepNumber,
    required int maxSteps,
    String previousReflection = "",
  }) async {
    final base64Image = base64Encode(screenshotPng);

    final prompt = """
Task: $task
Step: $stepNumber of $maxSteps
Reflection: ${previousReflection.isEmpty ? "None yet." : previousReflection}

Analyze this phone screenshot. Provide:
### Previous Action Verification
Did the previous step work?
### Screenshot Analysis
Describe visible screen UI elements relevant to the goal.
### Next Action
State the single next concrete action.
```python
self.click(action="click", element_description="exact description of target button or field")
```
(Or self.type(action="type", text="text to enter"), self.scroll(direction="down"), or DONE / FAIL)
""";

    final body = jsonEncode({
      "model": plannerModel,
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/png;base64,$base64Image"
              }
            }
          ]
        }
      ],
      "temperature": 0.1,
    });

    final res = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (res.statusCode != 200) {
      return AgentAction(
        type: ActionType.fail,
        thought: "Planner call failed: HTTP ${res.statusCode}",
      );
    }

    final data = jsonDecode(res.body);
    final reply = data['choices']?[0]?['message']?['content'] as String? ?? "";
    final code = _extractCode(reply);
    final thought = _extractThought(reply);

    return AgentAction.fromPlan(thought, code);
  }

  /// Step 2: Grounding Model (UI-TARS) pinpoints exact [x, y] coordinates on the scaled image
  Future<List<double>?> groundElementCoordinates({
    required String elementDescription,
    required Uint8List screenshotPng,
  }) async {
    final base64Image = base64Encode(screenshotPng);

    final prompt = "Find '$elementDescription' on this screen. Output the center coordinate as [x, y] between 0 and 1000.";

    final body = jsonEncode({
      "model": groundingModel,
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/png;base64,$base64Image"
              }
            }
          ]
        }
      ],
      "temperature": 0.0,
    });

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final content = data['choices']?[0]?['message']?['content'] as String? ?? "";
        final reg = RegExp(r'\[\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\]');
        final match = reg.firstMatch(content);
        if (match != null) {
          final rawX = double.tryParse(match.group(1)!) ?? 500.0;
          final rawY = double.tryParse(match.group(2)!) ?? 500.0;
          return [rawX, rawY];
        }
      }
    } catch (_) {}
    return null;
  }

  static String _extractCode(String text) {
    final reg = RegExp(r'```python\s*([\s\S]*?)\s*```');
    final match = reg.firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    if (text.toUpperCase().contains("DONE")) return "DONE";
    if (text.toUpperCase().contains("FAIL")) return "FAIL";
    return "";
  }

  static String _extractThought(String text) {
    final reg = RegExp(r'###\s*Next Action\s*([\s\S]*?)(?:```|$)');
    final match = reg.firstMatch(text);
    return match?.group(1)?.trim() ?? text.split('\n').first;
  }
}
