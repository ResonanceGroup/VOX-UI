# UltraVox STT and Kokoro TTS Node.js Integration Summary

This document summarizes how to interact with UltraVox STT and Kokoro TTS from a Node.js application.

## UltraVox STT

UltraVox interaction involves a backend REST API call to initiate a session and a client-side SDK (usable in Node.js) to manage the real-time connection.

1. **API/SDK:**
    * **REST API:** Used by the backend to create calls (`POST /api/v1/calls`) and obtain a `joinUrl`. (Docs: <http://docs.ultravox.ai/api-reference>)
    * **JavaScript SDK (`ultravox-client`):** Used by the Node.js application to connect to the call using the `joinUrl` and handle real-time events. (NPM: `npm install ultravox-client`, Docs: <https://docs.ultravox.ai/sdk-reference/introduction>, GitHub: <https://github.com/fixie-ai/ultravox-client-sdk-js>)

2. **Connection Method:**
    * Initial call creation via HTTPS REST request.
    * Real-time session management via the SDK, likely using WebSockets internally (abstracted by the SDK).

3. **Data Formats (Sending Audio for STT):**
    * The SDK typically manages microphone input directly in client environments (browsers).
    * For sending audio *from* Node.js (e.g., pre-recorded), the mechanism isn't explicitly documented in the visited pages and may require further investigation or different API endpoints if available. The primary use case seems to be capturing user audio via a connected client.

4. **Data Formats (Receiving Text from STT):**
    * Listen to the `transcripts` event on the `UltravoxSession` object.
    * Data format: Array of transcript objects: `{ text: string, isFinal: boolean, speaker: 'user' | 'agent', medium: 'voice' | 'text' }`. Filter by `speaker: 'user'`.

    ```javascript
    // Assuming 'session' is an initialized UltravoxSession
    session.addEventListener('transcripts', (event) => {
      const userTranscripts = session.transcripts.filter(t => t.speaker === 'user');
      console.log('User Transcripts:', userTranscripts);
      // Process final transcripts
      const finalTranscript = userTranscripts.find(t => t.isFinal);
      if (finalTranscript) {
        console.log('Final User Utterance:', finalTranscript.text);
        // Reset or handle final transcript
      }
    });
    ```

5. **Real-time Streaming:**
    * Yes, the SDK is designed for real-time.
    * Audio input is streamed from the client (user).
    * Transcript updates and session status (`connecting`, `listening`, `thinking`, `speaking`) are received via event listeners (`transcripts`, `status`).

6. **Configuration Options:**
    * `joinUrl`: Required, obtained from the REST API `Create Call` response.
    * `clientVersion` (Optional): String for application version tracking when calling `joinCall`.
    * `experimentalMessages` (Optional): Array (e.g., `["debug"]`) passed to `new UltravoxSession()` constructor to enable debug logs.

## Kokoro TTS

Kokoro TTS interaction in Node.js is handled locally using the `kokoro-js` library, which runs the model directly.

1. **API/SDK:**
    * **JavaScript Library (`kokoro-js`):** Runs the TTS model locally. (NPM: `npm install kokoro-js`, Docs: <https://www.npmjs.com/package/kokoro-js>, Model: <https://huggingface.co/hexgrad/Kokoro-82M>)

2. **Connection Method:**
    * Local processing. The library downloads/uses ONNX model files and runs inference using Transformers.js with a CPU backend. No external API calls needed for generation itself after setup.

3. **Data Formats (Sending Text for TTS):**
    * Plain JavaScript string passed to `tts.generate()` or pushed to the `TextSplitterStream` for `tts.stream()`.

4. **Data Formats (Receiving Audio from TTS):**
    * The `generate` and `stream` methods yield/return an `audio` object. This object has a `.save('filename.wav')` method. The internal format is likely raw audio samples (e.g., Float32Array). WAV is the documented output format.

5. **Real-time Streaming:**
    * Yes, using `tts.stream()` combined with `TextSplitterStream`. Text can be pushed incrementally, and audio chunks are yielded asynchronously.

    ```javascript
    import { KokoroTTS, TextSplitterStream } from "kokoro-js";

    async function runKokoroStream() {
      const model_id = "onnx-community/Kokoro-82M-v1.0-ONNX";
      const tts = await KokoroTTS.from_pretrained(model_id, {
        dtype: "q8", // Or "fp32", "fp16", etc.
        device: "cpu", // Use "cpu" for Node.js
      });

      const splitter = new TextSplitterStream();
      const stream = tts.stream(splitter);

      // Process audio chunks as they arrive
      (async () => {
        let i = 0;
        for await (const { text, phonemes, audio } of stream) {
          console.log(`Received chunk for: "${text}"`);
          // Save or process the audio chunk (e.g., stream to client)
          audio.save(`output_chunk_${i++}.wav`);
        }
        console.log("Streaming finished.");
      })();

      // Push text to the stream
      const inputText = "This is a test of streaming text to speech.";
      const words = inputText.match(/\s*\S+/g) || [];
      for (const word of words) {
        splitter.push(word);
        await new Promise(resolve => setTimeout(resolve, 50)); // Simulate delay
      }

      // Signal end of text
      splitter.close();
    }

    runKokoroStream();
    ```

6. **Configuration Options:**
    * `model_id`: Hugging Face model ID (e.g., `"onnx-community/Kokoro-82M-v1.0-ONNX"`).
    * `dtype`: Model quantization type (`"fp32"`, `"fp16"`, `"q8"`, `"q4"`, `"q4f16"`). Affects performance and quality.
    * `device`: Execution backend (`"cpu"` for Node.js, `"wasm"` or `"webgpu"` for web).
    * `voice`: Specific voice to use (e.g., `"af_heart"`). Get list via `tts.list_voices()`. Passed to `generate` or `stream` methods.
