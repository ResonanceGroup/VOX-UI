# Phi-4 Multimodal Interaction from Node.js Research Summary

This document summarizes findings on how to interact with the Microsoft Phi-4 Multimodal model from a Node.js application, focusing on voice and text interaction.

## 1. Official APIs, SDKs, or Libraries

*   **Primary Method (Python):** The most detailed documentation focuses on using the model locally via the Python `transformers` library (`AutoModelForCausalLM`, `AutoProcessor`).
*   **API Access (Recommended for Node.js):**
    *   **NVIDIA NIM:** Provides a REST API endpoint (`POST /nim/reference/microsoft-phi-4-multimodal-instruct-infer`). This is likely the most direct way to use the model via a managed service from Node.js using standard HTTP request libraries (e.g., `fetch`, `axios`).
    *   **vLLM:** The Hugging Face documentation mentions serving the model with `vLLM`, which exposes an OpenAI-compatible API. This could be self-hosted or potentially available through other providers. Node.js could interact with this using OpenAI client libraries or standard HTTP requests.
    *   **Azure AI Studio / Hugging Face:** Also mentioned as platforms hosting the model, likely offering their own API interfaces (details not found in the visited pages).
*   **Node.js SDK:** No specific, official Node.js SDK for Phi-4 Multimodal was identified in the researched documents.

## 2. Authentication Methods

*   **NVIDIA NIM / Azure / etc.:** Expected to use standard API Key authentication (e.g., Bearer token in the `Authorization` header). Specific details would be in the general documentation for the chosen platform (NVIDIA API Catalog, Azure AI).
*   **Self-hosted vLLM:** Authentication would depend on the vLLM server configuration (might be none, basic auth, or API key).
*   **Local Python:** May require Hugging Face Hub token for downloading models/assets.

## 3. Data Formats for Sending Audio/Text Prompts (Input)

*   **Prompt Structure:** Uses a specific chat format with special tokens:
    *   Text: `<|user|>Your text prompt<|end|>`
    *   Audio: `<|user|><|audio_1|>Your text prompt related to audio<|end|>`
    *   Combined: `<|user|><|image_1|><|audio_1|>Your text prompt related to image/audio<|end|>`
*   **Text:** Sent as strings within the prompt structure.
*   **Audio:**
    *   Referenced by `<|audio_1|>` token in the prompt.
    *   For REST APIs (like NVIDIA NIM), audio data likely needs to be provided as a **URL** accessible by the API server or as a **base64-encoded string** within the JSON payload.
    *   Supported formats include those loadable by Python's `soundfile` (e.g., WAV, FLAC, MP3 mentioned in NVIDIA docs).
    *   Recommended max length: ~40 seconds (up to 30 mins for summarization tasks).
*   **API Payload (Conceptual for NVIDIA NIM/vLLM):** Likely a JSON object following OpenAI's chat completion structure, but adapted for multimodal input. Example structure (needs verification):
    ```json
    {
      "model": "microsoft/phi-4-multimodal-instruct",
      "messages": [
        {
          "role": "user",
          "content": [
            { "type": "text", "text": "<|audio_1|>Transcribe this audio.<|end|>" },
            { "type": "audio_url", "audio_url": { "url": "data:audio/wav;base64,..." } } // Or a public URL
            // Or potentially: { "type": "audio_data", "audio_data": "BASE64_ENCODED_STRING" }
          ]
        }
      ],
      "max_tokens": 500,
      "stream": false // Or true if supported/desired
      // Other parameters like temperature, top_p etc.
    }
    ```

## 4. Data Formats for Receiving Text/Audio Responses (Output)

*   The model generates **text output only**.
*   API responses will be JSON objects containing the generated text, typically within a structure similar to OpenAI's API response (e.g., under `choices[0].message.content`).

## 5. Methods for Real-time Streaming Input/Output

*   **Input Streaming:** Not typically supported by standard REST APIs for audio/image data. Unlikely for NVIDIA NIM's POST endpoint. Might be possible with specific protocols like WebSockets if an endpoint supports it (not indicated in researched docs).
*   **Output Streaming:**
    *   Possible with OpenAI-compatible APIs (like vLLM) if the `stream: true` parameter is set in the request. The response would be Server-Sent Events (SSE).
    *   NVIDIA NIM *might* support response streaming (SSE) if the underlying engine does, but this wasn't explicitly confirmed on the visited pages. Needs checking in detailed API endpoint specs or general NIM documentation.

## 6. Key Configuration Parameters

*   Standard LLM generation parameters (sent in the API request payload): `max_tokens` (or `max_new_tokens`), `temperature`, `top_p`, `stop` sequences, etc.
*   Platform-specific parameters (e.g., for vLLM server deployment).

## Code Snippets

*   **Python (Hugging Face `transformers` - Local):**
    ```python
    # (Requires installing transformers, torch, soundfile, requests, Pillow, accelerate, flash-attn)
    import requests
    import torch
    import os
    import io
    from PIL import Image
    import soundfile as sf
    from transformers import AutoModelForCausalLM, AutoProcessor, GenerationConfig
    from urllib.request import urlopen

    # Define model path
    model_path = "microsoft/Phi-4-multimodal-instruct"

    # Load model and processor
    # Ensure you have enough GPU memory and compatible hardware (Ampere+ for flash_attention_2)
    processor = AutoProcessor.from_pretrained(model_path, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        device_map="cuda", # Or "auto" or specific device
        torch_dtype="auto", # Or torch.float16 / torch.bfloat16
        trust_remote_code=True,
        # Change attention to "eager" for older GPUs (V100 or earlier)
        _attn_implementation='flash_attention_2',
    ).eval() # Use .eval() for inference

    # Load generation config
    generation_config = GenerationConfig.from_pretrained(model_path)
    # You can customize generation config here, e.g., generation_config.temperature = 0.7

    # Define prompt structure
    user_prompt = '<|user|>'
    assistant_prompt = '<|assistant|>'
    prompt_suffix = '<|end|>'

    # --- Audio Example ---
    print("\\n--- AUDIO PROCESSING ---")
    audio_url = "https://upload.wikimedia.org/wikipedia/commons/b/b0/Barbara_Sahakian_BBC_Radio4_The_Life_Scientific_29_May_2012_b01j5j24.flac"
    speech_prompt = "Transcribe the audio to text."
    prompt = f'{user_prompt}<|audio_1|>{speech_prompt}{prompt_suffix}{assistant_prompt}'
    print(f'>>> Prompt\\n{prompt}')

    # Download and open audio file
    try:
        audio_data = urlopen(audio_url).read()
        audio, samplerate = sf.read(io.BytesIO(audio_data))

        # Process with the model
        inputs = processor(text=prompt, audios=[(audio, samplerate)], return_tensors='pt').to(model.device) # Ensure tensors are on the same device as the model

        # Generate response
        with torch.no_grad(): # Use no_grad for inference efficiency
             generate_ids = model.generate(
                 **inputs,
                 max_new_tokens=1000,
                 generation_config=generation_config,
             )
        # Decode only the newly generated tokens
        generate_ids = generate_ids[:, inputs['input_ids'].shape[1]:]
        response = processor.batch_decode(
            generate_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False
        )[0]
        print(f'>>> Response\\n{response}')

    except Exception as e:
        print(f"Error processing audio: {e}")

    # --- Image Example (from HF page) ---
    # print("\\n--- IMAGE PROCESSING ---")
    # image_url = 'https://www.ilankelman.org/stopsigns/australia.jpg'
    # image_prompt_text = "What is shown in this image?"
    # prompt = f'{user_prompt}<|image_1|>{image_prompt_text}{prompt_suffix}{assistant_prompt}'
    # print(f'>>> Prompt\\n{prompt}')
    # try:
    #     image = Image.open(requests.get(image_url, stream=True).raw)
    #     inputs = processor(text=prompt, images=image, return_tensors='pt').to(model.device)
    #     with torch.no_grad():
    #         generate_ids = model.generate(**inputs, max_new_tokens=1000, generation_config=generation_config)
    #     generate_ids = generate_ids[:, inputs['input_ids'].shape[1]:]
    #     response = processor.batch_decode(generate_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False)[0]
    #     print(f'>>> Response\\n{response}')
    # except Exception as e:
    #     print(f"Error processing image: {e}")
    ```
*   **Node.js (Conceptual `fetch` for NVIDIA NIM API):**
    ```javascript
    // NOTE: This is conceptual and requires verification of the actual
    // NVIDIA NIM endpoint URL, API key handling, and exact payload structure for audio.
    // You might need a library like 'axios' or use the built-in 'node-fetch'.

    // Assuming you have node-fetch installed: npm install node-fetch
    // Or use native fetch in Node.js v18+

    async function callPhi4Nvidia(apiKey, promptText, audioFilePath) {
      // Replace with your actual NVIDIA API Catalog endpoint URL for Phi-4 Multimodal
      const API_ENDPOINT = 'YOUR_NVIDIA_API_ENDPOINT/v1/chat/completions'; // Example structure
      const MODEL_NAME = 'microsoft/phi-4-multimodal-instruct'; // Or the specific ID used by NVIDIA

      // Read audio file and encode as base64
      const fs = require('fs').promises;
      let audioBase64;
      try {
        const audioBuffer = await fs.readFile(audioFilePath);
        audioBase64 = audioBuffer.toString('base64');
      } catch (err) {
        console.error(`Error reading audio file ${audioFilePath}:`, err);
        throw err;
      }

      // Construct the payload - Structure needs verification from NVIDIA docs!
      // This assumes an OpenAI-like structure adapted for multimodal.
      const payload = {
        model: MODEL_NAME,
        messages: [
          {
            role: "user",
            // Content might be an array for multimodal
            content: [
              { type: "text", text: `<|audio_1|>${promptText}<|end|>` },
              // Option 1: Data URL (Common for web contexts)
              { type: "audio_url", audio_url: { url: `data:audio/wav;base64,${audioBase64}` } }
              // Option 2: Direct base64 (Less common, depends on API spec)
              // { type: "audio_data", audio_data: audioBase64 }
              // Option 3: Public URL (If audio is hosted publicly)
              // { type: "audio_url", audio_url: { url: "YOUR_PUBLIC_AUDIO_URL" } }
            ]
            // Simpler structure if content is just a string with special tokens:
            // content: `<|audio_1|>${promptText}<|end|>` // And audio sent differently? Needs clarification.
          }
        ],
        max_tokens: 500,
        stream: false, // Set to true to attempt streaming
        temperature: 0.7 // Example parameter
      };

      console.log("Sending payload:", JSON.stringify(payload, null, 2).substring(0, 500) + "..."); // Log truncated payload

      try {
        const response = await fetch(API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`, // Standard Bearer token auth
            'Accept': 'application/json' // Or 'text/event-stream' for streaming
          },
          body: JSON.stringify(payload)
        });

        console.log(`Response Status: ${response.status}`);

        if (!response.ok) {
          const errorBody = await response.text();
          console.error("API Error Body:", errorBody);
          throw new Error(`HTTP error! status: ${response.status}, body: ${errorBody}`);
        }

        if (payload.stream && response.headers.get('content-type')?.includes('text/event-stream')) {
           console.log("Handling SSE stream...");
           // Process Server-Sent Events (SSE) stream
           // Example: Read the stream chunk by chunk
           const reader = response.body.getReader();
           const decoder = new TextDecoder();
           while (true) {
             const { done, value } = await reader.read();
             if (done) break;
             const chunk = decoder.decode(value);
             // Process SSE chunk (usually starts with 'data: ')
             console.log("Stream chunk:", chunk);
             // Extract content from 'data: {...}' lines
           }
           return "Streaming finished"; // Or accumulate results
        } else {
          // Handle regular JSON response
          const data = await response.json();
          console.log("API Response JSON:", JSON.stringify(data, null, 2));
          // Extract the actual text response (path might vary based on actual API structure)
          const textResponse = data.choices?.[0]?.message?.content || JSON.stringify(data);
          console.log("Generated Text:", textResponse);
          return data; // Return the full JSON response
        }
      } catch (error) {
        console.error("Error calling Phi-4 API:", error);
        throw error;
      }
    }

    // --- Example Usage (replace placeholders) ---
    /*
    const MY_NVIDIA_API_KEY = 'YOUR_KEY_HERE';
    const PROMPT = 'Transcribe the audio.';
    const AUDIO_FILE = './path/to/your/audio.wav';

    callPhi4Nvidia(MY_NVIDIA_API_KEY, PROMPT, AUDIO_FILE)
      .then(result => console.log("API call successful."))
      .catch(err => console.error("API call failed."));
    */
    ```

## Sources

*   Hugging Face Model Card: `https://huggingface.co/microsoft/Phi-4-multimodal-instruct`
*   NVIDIA API Docs: `https://docs.api.nvidia.com/nim/reference/microsoft-phi-4-multimodal-instruct`

## Further Research Needed

*   Exact JSON payload structure for multimodal input (audio/image) for the specific API endpoint chosen (NVIDIA NIM, vLLM, Azure). How is audio/image data actually passed?
*   Confirmation of authentication method and specific header requirements for the chosen API platform.
*   Confirmation of whether response streaming (SSE) is supported by the chosen API endpoint and how to enable/handle it.
*   Official API documentation for Azure AI Studio's Phi-4 endpoint if considering that platform.