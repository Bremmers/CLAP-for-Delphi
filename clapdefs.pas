unit clapdefs;

//Delphi translation of the CLAP audio plugin header files from https://github.com/free-audio/clap
//MIT license

{
 * CLAP - CLever Audio Plugin
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~
 *
 * Copyright (c) 2014...2022 Alexandre BIQUE <bique.alexandre@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 }

interface

uses
  System.SysUtils;

type
  uint16_t = UInt16;
  uint32_t = UInt32;
  uint64_t = UInt64;
  int16_t = Int16;
  int32_t = Int32;
  int64_t = Int64;
  size_t = NativeUInt;

//version.h

// This is the major ABI and API design
// Version 0.X.Y correspond to the development stage, API and ABI are not stable
// Version 1.X.Y correspond to the release stage, API and ABI are stable
  Tclap_version = record
    major: uint32_t;
    minor: uint32_t;
    revision: uint32_t;
  end;

const
  CLAP_VERSION_MAJOR = 1;
  CLAP_VERSION_MINOR = 2;
  CLAP_VERSION_REVISION = 3;

  CLAP_VERSION: Tclap_version = (
    major: CLAP_VERSION_MAJOR;
    minor: CLAP_VERSION_MINOR;
    revision: CLAP_VERSION_REVISION;
  );

// versions 0.x.y were used during development stage and aren't compatible
function clap_version_is_compatible(const v: Tclap_version): boolean; inline;


//string-sizes.h

const
  // String capacity for names that can be displayed to the user.
  CLAP_NAME_SIZE = 256;
  // String capacity for describing a path, like a parameter in a module hierarchy or path within a
  // set of nested track groups.
  //
  // This is not suited for describing a file path on the disk, as NTFS allows up to 32K long
  // paths.
  CLAP_PATH_SIZE = 1024;


//id.h

type
  Tclap_id = uint32_t;

const
  CLAP_INVALID_ID = UINT32.MaxValue;


//fixedpoint.h

/// We use fixed point representation of beat time and seconds time
/// Usage:
///   double x = ...; // in beats
///   clap_beattime y = round(CLAP_BEATTIME_FACTOR * x);

// This will never change
const
  CLAP_BEATTIME_FACTOR = int64_t(1) shl 31;
  CLAP_SECTIME_FACTOR = int64_t(1) shl 31;

type
  Tclap_beattime = int64_t;
  Tclap_sectime = int64_t;


//color.h

type
  Tclap_color = record
    alpha: byte;
    red: byte;
    green: byte;
    blue: byte;
  end;
  Pclap_color = ^Tclap_color;

const
  CLAP_COLOR_TRANSPARENT: Tclap_color = (
    alpha: 0; red: 0; green: 0; blue: 0
  );

//events.h

// event header
// All clap events start with an event header to determine the overall
// size of the event and its type and space (a namespacing for types).
// clap_event objects are contiguous regions of memory which can be copied
// with a memcpy of `size` bytes starting at the top of the header. As
// such, be very careful when designing clap events with internal pointers
// and other non-value-types to consider the lifetime of those members.
type
  Tclap_event_header = record
    size: uint32_t;      // event size including this header, eg: sizeof (clap_event_note)
    time: uint32_t;      // sample offset within the buffer for this event
    space_id: uint16_t;  // event space, see clap_host_event_registry
    &type: uint16_t;     // event type
    flags: uint32_t;     // see clap_event_flags
  end;
  Pclap_event_header = ^Tclap_event_header;

// The clap core event space
const
  CLAP_CORE_EVENT_SPACE_ID = 0;

  // Indicate a live user event, for example a user turning a physical knob
  // or playing a physical key.
  CLAP_EVENT_IS_LIVE = 1 shl 0;

  // indicate that the event should not be recorded.
  // For example this is useful when a parameter changes because of a MIDI CC,
  // because if the host records both the MIDI CC automation and the parameter
  // automation there will be a conflict.
  CLAP_EVENT_DONT_RECORD = 1 shl 1;

// Some of the following events overlap, a note on can be expressed with:
// - CLAP_EVENT_NOTE_ON
// - CLAP_EVENT_MIDI
// - CLAP_EVENT_MIDI2
//
// The preferred way of sending a note event is to use CLAP_EVENT_NOTE_*.
//
// The same event must not be sent twice: it is forbidden to send a the same note on
// encoded with both CLAP_EVENT_NOTE_ON and CLAP_EVENT_MIDI.
//
// The plugins are encouraged to be able to handle note events encoded as raw midi or midi2,
// or implement clap_plugin_event_filter and reject raw midi and midi2 events.

  // NOTE_ON and NOTE_OFF represents a key pressed and key released event, respectively.
  // A NOTE_ON with a velocity of 0 is valid and should not be interpreted as a NOTE_OFF.
  //
  // NOTE_CHOKE is meant to choke the voice(s), like in a drum machine when a closed hihat
  // chokes an open hihat. This event can be sent by the host to the plugin. Here are two use
  // cases:
  // - a plugin is inside a drum pad in Bitwig Studio's drum machine, and this pad is choked by
  //   another one
  // - the user double-clicks the DAW's stop button in the transport which then stops the sound on
  //   every track
  //
  // NOTE_END is sent by the plugin to the host. The port, channel, key and note_id are those given
  // by the host in the NOTE_ON event. In other words, this event is matched against the
  // plugin's note input port.
  // NOTE_END is useful to help the host to match the plugin's voice life time.
  //
  // When using polyphonic modulations, the host has to allocate and release voices for its
  // polyphonic modulator. Yet only the plugin effectively knows when the host should terminate
  // a voice. NOTE_END solves that issue in a non-intrusive and cooperative way.
  //
  // CLAP assumes that the host will allocate a unique voice on NOTE_ON event for a given port,
  // channel and key. This voice will run until the plugin will instruct the host to terminate
  // it by sending a NOTE_END event.
  //
  // Consider the following sequence:
  // - process()
  //    Host->Plugin NoteOn(port:0, channel:0, key:16, time:t0)
  //    Host->Plugin NoteOn(port:0, channel:0, key:64, time:t0)
  //    Host->Plugin NoteOff(port:0, channel:0, key:16, t1)
  //    Host->Plugin NoteOff(port:0, channel:0, key:64, t1)
  //    # on t2, both notes did terminate
  //    Host->Plugin NoteOn(port:0, channel:0, key:64, t3)
  //    # Here the plugin finished processing all the frames and will tell the host
  //    # to terminate the voice on key 16 but not 64, because a note has been started at t3
  //    Plugin->Host NoteEnd(port:0, channel:0, key:16, time:ignored)
  //
  // Those four events use clap_event_note.
  CLAP_EVENT_NOTE_ON = 0;
  CLAP_EVENT_NOTE_OFF = 1;
  CLAP_EVENT_NOTE_CHOKE = 2;
  CLAP_EVENT_NOTE_END = 3;

  // Represents a note expression.
  // Uses clap_event_note_expression.
  CLAP_EVENT_NOTE_EXPRESSION = 4;

  // PARAM_VALUE sets the parameter's value; uses clap_event_param_value.
  // PARAM_MOD sets the parameter's modulation amount; uses clap_event_param_mod.
  //
  // The value heard is: param_value + param_mod.
  //
  // In case of a concurrent global value/modulation versus a polyphonic one,
  // the voice should only use the polyphonic one and the polyphonic modulation
  // amount will already include the monophonic signal.
  CLAP_EVENT_PARAM_VALUE = 5;
  CLAP_EVENT_PARAM_MOD = 6;

  // Indicates that the user started or finished adjusting a knob.
  // This is not mandatory to wrap parameter changes with gesture events, but this improves
  // the user experience a lot when recording automation or overriding automation playback.
  // Uses clap_event_param_gesture.
  CLAP_EVENT_PARAM_GESTURE_BEGIN = 7;
  CLAP_EVENT_PARAM_GESTURE_END = 8;

  CLAP_EVENT_TRANSPORT = 9;   // update the transport info; clap_event_transport
  CLAP_EVENT_MIDI = 10;       // raw midi event; clap_event_midi
  CLAP_EVENT_MIDI_SYSEX = 11; // raw midi sysex event; clap_event_midi_sysex
  CLAP_EVENT_MIDI2 = 12;      // raw midi 2 event; clap_event_midi2

type
// Note on, off, end and choke events.
//
// Clap addresses notes and voices using the 4-value tuple
// (port, channel, key, note_id). Note on/off/end/choke
// events and parameter modulation messages are delivered with
// these values populated.
//
// Values in a note and voice address are either >= 0 if they
// are specified, or -1 to indicate a wildcard. A wildcard
// means a voice with any value in that part of the tuple
// matches the message.
//
// For instance, a (PCKN) of (0, 3, -1, -1) will match all voices
// on channel 3 of port 0. And a PCKN of (-1, 0, 60, -1) will match
// all channel 0 key 60 voices, independent of port or note id.
//
// Especially in the case of note-on note-off pairs, and in the
// absence of voice stacking or polyphonic modulation, a host may
// choose to issue a note id only at note on. So you may see a
// message stream like
//
// CLAP_EVENT_NOTE_ON  [0,0,60,184]
// CLAP_EVENT_NOTE_OFF [0,0,60,-1]
//
// and the host will expect the first voice to be released.
// Well constructed plugins will search for voices and notes using
// the entire tuple.
//
// In the case of note on events:
// - The port, channel and key must be specified with a value >= 0
// - A note-on event with a '-1' for port, channel or key is invalid and
//   can be rejected or ignored by a plugin or host.
// - A host which does not support note ids should set the note id to -1.
//
// In the case of note choke or end events:
// - the velocity is ignored.
// - key and channel are used to match active notes
// - note_id is optionally provided by the host
  Tclap_event_note = record
    header: Tclap_event_header;

    note_id: int32_t;     // host provided note id >= 0, or -1 if unspecified or wildcard
    port_index: int16_t;  // port index from ext/note-ports; -1 for wildcard
    channel: int16_t;     // 0..15, same as MIDI1 Channel Number, -1 for wildcard
    key: int16_t;         // 0..127, same as MIDI1 Key Number (60==Middle C), -1 for wildcard
    velocity: double;     // 0..1
  end;

// Note Expressions are well named modifications of a voice targeted to
// voices using the same wildcard rules described above. Note Expressions are delivered
// as sample accurate events and should be applied at the sample when received.
//
// Note expressions are a statement of value, not cumulative. A PAN event of 0 followed by 1
// followed by 0.5 would pan hard left, hard right, and center. They are intended as
// an offset from the non-note-expression voice default. A voice which had a volume of
// -20db absent note expressions which received a +4db note expression would move the
// voice to -16db.
//
// A plugin which receives a note expression at the same sample as a NOTE_ON event
// should apply that expression to all generated samples. A plugin which receives
// a note expression after a NOTE_ON event should initiate the voice with default
// values and then apply the note expression when received. A plugin may make a choice
// to smooth note expression streams.
const
  // with 0 < x <= 4, plain = 20 * log(x)
  CLAP_NOTE_EXPRESSION_VOLUME = 0;

  // pan, 0 left, 0.5 center, 1 right
  CLAP_NOTE_EXPRESSION_PAN = 1;

  // Relative tuning in semitones, from -120 to +120. Semitones are in
  // equal temperament and are doubles; the resulting note would be
  // retuned by `100 * evt->value` cents.
  CLAP_NOTE_EXPRESSION_TUNING = 2;

  // 0..1
  CLAP_NOTE_EXPRESSION_VIBRATO = 3;
  CLAP_NOTE_EXPRESSION_EXPRESSION = 4;
  CLAP_NOTE_EXPRESSION_BRIGHTNESS = 5;
  CLAP_NOTE_EXPRESSION_PRESSURE = 6;

type
  Tclap_note_expression = int32_t;

  Tclap_event_note_expression  = record
    header: Tclap_event_header;

    expression_id: Tclap_note_expression;

    // target a specific note_id, port, key and channel, with
    // -1 meaning wildcard, per the wildcard discussion above
    note_id: int32_t;
    port_index: int16_t;
    channel: int16_t;
    key: int16_t;

    value: double; // see expression for the range
  end;

  Tclap_event_param_value = record
    header: Tclap_event_header;

    // target parameter
    param_id: Tclap_id; // @ref clap_param_info.id
    cookie: pointer;    // @ref clap_param_info.cookie

    // target a specific note_id, port, key and channel, with
    // -1 meaning wildcard, per the wildcard discussion above
    note_id: int32_t;
    port_index: int16_t;
    channel: int16_t;
    key: int16_t;

    value: double;
  end;

  Tclap_event_param_mod = record
    header: Tclap_event_header;

    // target parameter
    param_id: Tclap_id; // @ref clap_param_info.id
    cookie: pointer;    // @ref clap_param_info.cookie

    // target a specific note_id, port, key and channel, with
    // -1 meaning wildcard, per the wildcard discussion above
    note_id: int32_t;
    port_index: int16_t;
    channel: int16_t;
    key: int16_t;

    amount: double; // modulation amount
  end;

  Tclap_event_param_gesture = record
    header: Tclap_event_header;

    // target parameter
    param_id: Tclap_id; // @ref clap_param_info.id
  end;

const
  CLAP_TRANSPORT_HAS_TEMPO = 1 shl 0;
  CLAP_TRANSPORT_HAS_BEATS_TIMELINE = 1 shl 1;
  CLAP_TRANSPORT_HAS_SECONDS_TIMELINE = 1 shl 2;
  CLAP_TRANSPORT_HAS_TIME_SIGNATURE = 1 shl 3;
  CLAP_TRANSPORT_IS_PLAYING = 1 shl 4;
  CLAP_TRANSPORT_IS_RECORDING = 1 shl 5;
  CLAP_TRANSPORT_IS_LOOP_ACTIVE = 1 shl 6;
  CLAP_TRANSPORT_IS_WITHIN_PRE_ROLL = 1 shl 7;

type
// clap_event_transport provides song position, tempo, and similar information
// from the host to the plugin. There are two ways a host communicates these values.
// In the `clap_process` structure sent to each processing block, the host may
// provide a transport structure which indicates the available information at the
// start of the block. If the host provides sample-accurate tempo or transport changes,
// it can also provide subsequent inter-block transport updates by delivering a new event.
  Tclap_event_transport = record
    header: Tclap_event_header;

    flags: uint32_t; // see clap_transport_flags

    song_pos_beats: Tclap_beattime;  // position in beats
    song_pos_seconds: Tclap_sectime; // position in seconds

    tempo: double;     // in bpm
    tempo_inc: double; // tempo increment for each sample and until the next
                       // time info event

    loop_start_beats: Tclap_beattime;
    loop_end_beats: Tclap_beattime;
    loop_start_seconds: Tclap_sectime;
    loop_end_seconds: Tclap_sectime;

    bar_start: Tclap_beattime; // start pos of the current bar
    bar_number: int32_t;       // bar at song pos 0 has the number 0

    tsig_num: uint16_t;   // time signature numerator
    tsig_denom: uint16_t; // time signature denominator
  end;
  Pclap_event_transport = ^Tclap_event_transport;

  Tclap_event_midi = record
    header: Tclap_event_header;

    port_index: uint16_t;
    data: array[0..2] of byte;
  end;
  
// clap_event_midi_sysex contains a pointer to a sysex contents buffer.
// The lifetime of this buffer is (from host->plugin) only the process
// call in which the event is delivered or (from plugin->host) only the
// duration of a try_push call.
//
// Since `clap_output_events.try_push` requires hosts to make a copy of
// an event, host implementers receiving sysex messages from plugins need
// to take care to both copy the event (so header, size, etc...) but
// also memcpy the contents of the sysex pointer to host-owned memory, and
// not just copy the data pointer.
//
// Similarly plugins retaining the sysex outside the lifetime of a single
// process call must copy the sysex buffer to plugin-owned memory.
//
// As a consequence, the data structure pointed to by the sysex buffer
// must be contiguous and copyable with `memcpy` of `size` bytes.
  Tclap_event_midi_sysex = record
    header: Tclap_event_header;

    port_index: uint16_t;
    buffer: pointer; // midi buffer. See lifetime comment above.
    size: uint32_t;
  end;

// While it is possible to use a series of midi2 event to send a sysex,
// prefer clap_event_midi_sysex if possible for efficiency.
  Tclap_event_midi2 = record
    header: Tclap_event_header;

    port_index: uint16_t;
    data: array[0..3] of uint32_t;
  end;

// Input event list. The host will deliver these sorted in sample order.
  Pclap_input_events = ^Tclap_input_events;
  Tclap_input_events = record
    ctx: TObject; // reserved pointer for the list

    // returns the number of events in the list
    //uint32_t (*size)(const struct clap_input_events *list);
    size: function(list: Pclap_input_events): uint32_t; cdecl;

    // Don't free the returned event, it belongs to the list
    //const clap_event_header_t *(*get)(const struct clap_input_events *list, uint32_t index);
    get: function(list: Pclap_input_events; index: uint32_t): Pclap_event_header; cdecl;
  end;

// Output event list. The plugin must insert events in sample sorted order when inserting events
  Pclap_output_events = ^Tclap_output_events;
  Tclap_output_events = record
    ctx: TObject; // reserved pointer for the list

    // Pushes a copy of the event
    // returns false if the event could not be pushed to the queue (out of memory?)
    //bool (*try_push)(const struct clap_output_events *list, const clap_event_header_t *event);
    try_push: function(list: Pclap_output_events; event: Pclap_event_header): boolean; cdecl;
  end;


//audio-buffer.h

type
// Sample code for reading a stereo buffer:
//
// bool isLeftConstant = (buffer->constant_mask & (1 << 0)) != 0;
// bool isRightConstant = (buffer->constant_mask & (1 << 1)) != 0;
//
// for (int i = 0; i < N; ++i) {
//    float l = data32[0][isLeftConstant ? 0 : i];
//    float r = data32[1][isRightConstant ? 0 : i];
// }
//
// Note: checking the constant mask is optional, and this implies that
// the buffer must be filled with the constant value.
// Rationale: if a buffer reader doesn't check the constant mask, then it may
// process garbage samples and in result, garbage samples may be transmitted
// to the audio interface with all the bad consequences it can have.
//
// The constant mask is a hint.
  Tclap_audio_buffer = record
    // Either data32 or data64 pointer will be set.
    data32: PPointerArray;
    data64: PPointerArray;
    channel_count: uint32_t;
    latency: uint32_t; // latency from/to the audio interface
    constant_mask: uint64_t;
  end;


//process.h

const
  // Processing failed. The output buffer must be discarded.
  CLAP_PROCESS_ERROR = 0;

  // Processing succeeded, keep processing.
  CLAP_PROCESS_CONTINUE = 1;

  // Processing succeeded, keep processing if the output is not quiet.
  CLAP_PROCESS_CONTINUE_IF_NOT_QUIET = 2;

  // Rely upon the plugin's tail to determine if the plugin should continue to process.
  // see clap_plugin_tail
  CLAP_PROCESS_TAIL = 3;

  // Processing succeeded, but no more processing is required,
  // until the next event or variation in audio input.
  CLAP_PROCESS_SLEEP = 4;

type
  Tclap_process_status = int32_t;

  Tclap_process = record
    // A steady sample time counter.
    // This field can be used to calculate the sleep duration between two process calls.
    // This value may be specific to this plugin instance and have no relation to what
    // other plugin instances may receive.
    //
    // Set to -1 if not available, otherwise the value must be greater or equal to 0,
    // and must be increased by at least `frames_count` for the next call to process.
    steady_time: uint64_t;
    // Number of frame to process
    frames_count: uint32_t;

    // time info at sample 0
    // If null, then this is a free running host, no transport events will be provided
    transport: Pclap_event_transport;

    // Audio buffers, they must have the same count as specified
    // by clap_plugin_audio_ports->count().
    // The index maps to clap_plugin_audio_ports->get().
    // Input buffer and its contents are read-only.
    audio_inputs: pointer { Pclap_audio_buffer_t };
    audio_outputs: pointer { Pclap_audio_buffer_t };
    audio_inputs_count: uint32_t;
    audio_outputs_count: uint32_t;

    // The input event list can't be modified.
    // Input read-only event list. The host will deliver these sorted in sample order.
    in_events: Pclap_input_events;

    // Output event list. The plugin must insert events in sample sorted order when inserting events
    out_events: Pclap_output_events;
  end;
  Pclap_process = ^Tclap_process;


//host.h

  Pclap_host = ^Tclap_host;
  Tclap_host = record
    clap_version: Tclap_version; // initialized to CLAP_VERSION

    host_data: TObject; // reserved pointer for the host

    // name and version are mandatory.
    name: PAnsiChar;    // eg: "Bitwig Studio"
    vendor: PAnsiChar;  // eg: "Bitwig GmbH"
    url: PAnsiChar;     // eg: "https://bitwig.com"
    version: PAnsiChar; // eg: "4.3", see plugin.h for advice on how to format the version

    // Query an extension.
    // The returned pointer is owned by the host.
    // It is forbidden to call it before plugin->init().
    // You can call it within plugin->init() call, and after.
    // [thread-safe]
    //const void *(*get_extension)(const struct clap_host *host, const char *extension_id);
    get_extension: function(host: Pclap_host; extension_id: PAnsiChar): pointer; cdecl;

    // Request the host to deactivate and then reactivate the plugin.
    // The operation may be delayed by the host.
    // [thread-safe]
    //void (*request_restart)(const struct clap_host *host);
    request_restart: procedure(host: Pclap_host); cdecl;

    // Request the host to activate and start processing the plugin.
    // This is useful if you have external IO and need to wake up the plugin from "sleep".
    // [thread-safe]
    //void (*request_process)(const struct clap_host *host);
    request_process: procedure(host: Pclap_host); cdecl;

    // Request the host to schedule a call to plugin->on_main_thread(plugin) on the main thread.
    // This callback should be called as soon as practicable, usually in the host application's next
    // available main thread time slice. Typically callbacks occur within 33ms / 30hz.
    // Despite this guidance, plugins should not make assumptions about the exactness of timing for
    // a main thread callback, but hosts should endeavour to be prompt. For example, in high load
    // situations the environment may starve the gui/main thread in favor of audio processing,
    // leading to substantially longer latencies for the callback than the indicative times given
    // here.
    // [thread-safe]
    //void (*request_callback)(const struct clap_host *host);
    request_callback: procedure(host: Pclap_host); cdecl;
  end;


//plugin.h

type
  TPAnsiCharArray = array[0..(High(Integer) div SizeOf(PChar))-1] of PAnsiChar;
  PPAnsiCharArray = ^TPAnsiCharArray;

  Tclap_plugin_descriptor = record
    clap_version: Tclap_version; // initialized to CLAP_VERSION

    // Mandatory fields must be set and must not be blank.
    // Otherwise the fields can be null or blank, though it is safer to make them blank.
    //
    // Some indications regarding id and version
    // - id is an arbitrary string which should be unique to your plugin,
    //   we encourage you to use a reverse URI eg: "com.u-he.diva"
    // - version is an arbitrary string which describes a plugin,
    //   it is useful for the host to understand and be able to compare two different
    //   version strings, so here is a regex like expression which is likely to be
    //   understood by most hosts: MAJOR(.MINOR(.REVISION)?)?( (Alpha|Beta) XREV)?
    id: PAnsiChar;          // eg: "com.u-he.diva, mandatory"
    name: PAnsiChar;        // eg: "Diva", mandatory
    vendor: PAnsiChar;      // eg: "u-he"
    url: PAnsiChar;         // eg: "https://u-he.com/products/diva/"
    manual_url: PAnsiChar;  // eg: "https://dl.u-he.com/manuals/plugins/diva/Diva-user-guide.pdf"
    support_url: PAnsiChar; // eg: "https://u-he.com/support/"
    version: PAnsiChar;     // eg: "1.4.4"
    description: PAnsiChar; // eg: "The spirit of analogue"

    // Arbitrary list of keywords.
    // They can be matched by the host indexer and used to classify the plugin.
    // The array of pointers must be null terminated.
    // For some standard features see plugin-features.h
    features: PPAnsiCharArray;
  end;
  Pclap_plugin_descriptor = ^Tclap_plugin_descriptor;

  Pclap_plugin = ^Tclap_plugin;
  Tclap_plugin = record
    desc: Pclap_plugin_descriptor;

    plugin_data: pointer; // reserved pointer for the plugin

    // Must be called after creating the plugin.
    // If init returns false, the host must destroy the plugin instance.
    // If init returns true, then the plugin is initialized and in the deactivated state.
    // Unlike in `plugin-factory::create_plugin`, in init you have complete access to the host
    // and host extensions, so clap related setup activities should be done here rather than in
    // create_plugin.
    // [main-thread]
    //bool (*init)(const struct clap_plugin *plugin);
    init: function(plugin: Pclap_plugin): boolean; cdecl;

    // Free the plugin and its resources.
    // It is required to deactivate the plugin prior to this call. */}
    // [main-thread & !active]
    //void (*destroy)(const struct clap_plugin *plugin);
    destroy: procedure(plugin: Pclap_plugin); cdecl;

    // Activate and deactivate the plugin.
    // In this call the plugin may allocate memory and prepare everything needed for the process
    // call. The process's sample rate will be constant and process's frame count will included in
    // the [min, max] range, which is bounded by [1, INT32_MAX].
    // In this call the plugin may call host-provided methods marked [being-activated].
    // Once activated the latency and port configuration must remain constant, until deactivation.
    // Returns true on success.
    // [main-thread & !active]
    //bool (*activate)(const struct clap_plugin *plugin,
    //                 double                    sample_rate,
    //                 uint32_t                  min_frames_count,
    //                 uint32_t                  max_frames_count);
    activate: function(plugin: Pclap_plugin; sample_rate: double; min_frames_count: uint32_t; max_frames_count: uint32_t): boolean; cdecl;
    // [main-thread & active]
    //void (*deactivate)(const struct clap_plugin *plugin);
    deactivate: procedure(plugin: Pclap_plugin); cdecl;

    // Call start processing before processing.
    // Returns true on success.
    // [audio-thread & active & !processing]
    //bool (*start_processing)(const struct clap_plugin *plugin);
    start_processing: function(plugin: Pclap_plugin): boolean; cdecl;
    // Call stop processing before sending the plugin to sleep.
    // [audio-thread & active & processing]
    //void (*stop_processing)(const struct clap_plugin *plugin);
    stop_processing: procedure(plugin: Pclap_plugin); cdecl;

    // - Clears all buffers, performs a full reset of the processing state (filters, oscillators,
    //   envelopes, lfo, ...) and kills all voices.
    // - The parameter's value remain unchanged.
    // - clap_process.steady_time may jump backward.
    //
    // [audio-thread & active]
    //void (*reset)(const struct clap_plugin *plugin);
    reset: procedure(plugin: Pclap_plugin); cdecl;

    // process audio, events, ...
    // All the pointers coming from clap_process_t and its nested attributes,
    // are valid until process() returns.
    // [audio-thread & active & processing]
    //clap_process_status (*process)(const struct clap_plugin *plugin, const clap_process_t *process);
    process: function(plugin: Pclap_plugin; process: Pclap_process): Tclap_process_status; cdecl;

    // Query an extension.
    // The returned pointer is owned by the plugin.
    // It is forbidden to call it before plugin->init().
    // You can call it within plugin->init() call, and after.
    // [thread-safe]
    //const void *(*get_extension)(const struct clap_plugin *plugin, const char *id);
    get_extension: function(plugin: Pclap_plugin; id: PAnsiChar): pointer; cdecl;

    // Called by the host on the main thread in response to a previous call to:
    //   host->request_callback(host);
    // [main-thread]
    //void (*on_main_thread)(const struct clap_plugin *plugin);
    on_main_thread: procedure(plugin: Pclap_plugin); cdecl;
  end;


//plugin-features.h

// This files provides a set of standard plugin features meant to be used
// within clap_plugin_descriptor.features.
//
// For practical reasons we'll avoid spaces and use `-` instead to facilitate
// scripts that generate the feature array.
//
// Non-standard features should be formatted as follow: "$namespace:$feature"

const

/////////////////////
// Plugin category //
/////////////////////

// Add this feature if your plugin can process note events and then produce audio
  CLAP_PLUGIN_FEATURE_INSTRUMENT = 'instrument';

// Add this feature if your plugin is an audio effect
  CLAP_PLUGIN_FEATURE_AUDIO_EFFECT = 'audio-effect';

// Add this feature if your plugin is a note effect or a note generator/sequencer
  CLAP_PLUGIN_FEATURE_NOTE_EFFECT = 'note-effect';

// Add this feature if your plugin converts audio to notes
  CLAP_PLUGIN_FEATURE_NOTE_DETECTOR = 'note-detector';

// Add this feature if your plugin is an analyzer
  CLAP_PLUGIN_FEATURE_ANALYZER = 'analyzer';

/////////////////////////
// Plugin sub-category //
/////////////////////////

  CLAP_PLUGIN_FEATURE_SYNTHESIZER = 'synthesizer';
  CLAP_PLUGIN_FEATURE_SAMPLER = 'sampler';
  CLAP_PLUGIN_FEATURE_DRUM = 'drum'; // For single drum
  CLAP_PLUGIN_FEATURE_DRUM_MACHINE = 'drum-machine';

  CLAP_PLUGIN_FEATURE_FILTER = 'filter';
  CLAP_PLUGIN_FEATURE_PHASER = 'phaser';
  CLAP_PLUGIN_FEATURE_EQUALIZER = 'equalizer';
  CLAP_PLUGIN_FEATURE_DEESSER = 'de-esser';
  CLAP_PLUGIN_FEATURE_PHASE_VOCODER = 'phase-vocoder';
  CLAP_PLUGIN_FEATURE_GRANULAR = 'granular';
  CLAP_PLUGIN_FEATURE_FREQUENCY_SHIFTER = 'frequency-shifter';
  CLAP_PLUGIN_FEATURE_PITCH_SHIFTER = 'pitch-shifter';

  CLAP_PLUGIN_FEATURE_DISTORTION = 'distortion';
  CLAP_PLUGIN_FEATURE_TRANSIENT_SHAPER = 'transient-shaper';
  CLAP_PLUGIN_FEATURE_COMPRESSOR = 'compressor';
  CLAP_PLUGIN_FEATURE_EXPANDER = 'expander';
  CLAP_PLUGIN_FEATURE_GATE = 'gate';
  CLAP_PLUGIN_FEATURE_LIMITER = 'limiter';

  CLAP_PLUGIN_FEATURE_FLANGER = 'flanger';
  CLAP_PLUGIN_FEATURE_CHORUS = 'chorus';
  CLAP_PLUGIN_FEATURE_DELAY = 'delay';
  CLAP_PLUGIN_FEATURE_REVERB = 'reverb';

  CLAP_PLUGIN_FEATURE_TREMOLO = 'tremolo';
  CLAP_PLUGIN_FEATURE_GLITCH = 'glitch';

  CLAP_PLUGIN_FEATURE_UTILITY = 'utility';
  CLAP_PLUGIN_FEATURE_PITCH_CORRECTION = 'pitch-correction';
  CLAP_PLUGIN_FEATURE_RESTORATION = 'restoration'; // repair the sound

  CLAP_PLUGIN_FEATURE_MULTI_EFFECTS = 'multi-effects';

  CLAP_PLUGIN_FEATURE_MIXING = 'mixing';
  CLAP_PLUGIN_FEATURE_MASTERING = 'mastering';

////////////////////////
// Audio Capabilities //
////////////////////////

  CLAP_PLUGIN_FEATURE_MONO = 'mono';
  CLAP_PLUGIN_FEATURE_STEREO = 'stereo';
  CLAP_PLUGIN_FEATURE_SURROUND = 'surround';
  CLAP_PLUGIN_FEATURE_AMBISONIC = 'ambisonic';


//universal-plugin-id.h

// Pair of plugin ABI and plugin identifier
type
  Tclap_universal_plugin_id = record
    // The plugin ABI name, in lowercase and null-terminated.
    // eg: "clap", "vst3", "vst2", "au", ...
    abi: PAnsiChar;
    // The plugin ID, null-terminated and formatted as follow:
    //
    // CLAP: use the plugin id
    //   eg: "com.u-he.diva"
    //
    // AU: format the string like "type:subt:manu"
    //   eg: "aumu:SgXT:VmbA"
    //
    // VST2: print the id as a signed 32-bits integer
    //   eg: "-4382976"
    //
    // VST3: print the id as a standard UUID
    //   eg: "123e4567-e89b-12d3-a456-426614174000"
    id: PAnsiChar;
  end;
  Pclap_universal_plugin_id = ^Tclap_universal_plugin_id;


//factory\plugin-factory.h

// Use it to retrieve const clap_plugin_factory_t* from
// clap_plugin_entry.get_factory()
const
  CLAP_PLUGIN_FACTORY_ID = AnsiString('clap.plugin-factory');

type
  Pclap_plugin_factory = ^Tclap_plugin_factory;
// Every method must be thread-safe.
// It is very important to be able to scan the plugin as quickly as possible.
//
// The host may use clap_plugin_invalidation_factory to detect filesystem changes
// which may change the factory's content.
  Tclap_plugin_factory = record
    // Get the number of plugins available.
    // [thread-safe]
    //uint32_t (*get_plugin_count)(const struct clap_plugin_factory *factory);
    get_plugin_count: function(factory: Pclap_plugin_factory): uint32_t; cdecl;

    // Retrieves a plugin descriptor by its index.
    // Returns null in case of error.
    // The descriptor must not be freed.
    // [thread-safe]
    //const clap_plugin_descriptor_t *(*get_plugin_descriptor)(
    //  const struct clap_plugin_factory *factory, uint32_t index);
    get_plugin_descriptor: function(factory: Pclap_plugin_factory; index: uint32_t): Pclap_plugin_descriptor; cdecl;

    // Create a clap_plugin by its plugin_id.
    // The returned pointer must be freed by calling plugin->destroy(plugin);
    // The plugin is not allowed to use the host callbacks in the create method.
    // Returns null in case of error.
    // [thread-safe]
    //const clap_plugin_t *(*create_plugin)(const struct clap_plugin_factory *factory,
    //                                      const clap_host_t                *host,
    //                                      const char                       *plugin_id);
    create_plugin: function(factory: Pclap_plugin_factory; host: Pclap_host; plugin_id: PAnsiChar): Pclap_plugin; cdecl;
  end;


//factory\draft\plugin-invalidation.h

// Use it to retrieve const clap_plugin_invalidation_factory_t* from
// clap_plugin_entry.get_factory()
const
  CLAP_PLUGIN_INVALIDATION_FACTORY_ID = AnsiString('clap.plugin-invalidation-factory/1');

type
  Tclap_plugin_invalidation_source = record
    // Directory containing the file(s) to scan, must be absolute
    directory: PAnsiChar;
    // globing pattern, in the form *.dll
    filename_glob: PAnsiChar;
    // should the directory be scanned recursively?
    recursive_scan: boolean;
  end;
  Pclap_plugin_invalidation_source = ^Tclap_plugin_invalidation_source;

// Used to figure out when a plugin needs to be scanned again.
// Imagine a situation with a single entry point: my-plugin.clap which then scans itself
// a set of "sub-plugins". New plugin may be available even if my-plugin.clap file doesn't change.
// This interfaces solves this issue and gives a way to the host to monitor additional files.
type
  Pclap_plugin_invalidation_factory = ^Tclap_plugin_invalidation_factory;
  Tclap_plugin_invalidation_factory = record
    // Get the number of invalidation source.
    //uint32_t (*count)(const struct clap_plugin_invalidation_factory *factory);
    count: function(factory: Pclap_plugin_invalidation_factory): uint32_t; cdecl;

    // Get the invalidation source by its index.
    // [thread-safe]
    //const clap_plugin_invalidation_source_t *(*get)(
    //  const struct clap_plugin_invalidation_factory *factory, uint32_t index);
    get: function(factory: Pclap_plugin_invalidation_factory; index: uint32_t): Pclap_plugin_invalidation_source; cdecl;

    // In case the host detected a invalidation event, it can call refresh() to let the
    // plugin_entry update the set of plugins available.
    // If the function returned false, then the plugin needs to be reloaded.
    //bool (*refresh)(const struct clap_plugin_invalidation_factory *factory);
    refresh: function(factory: Pclap_plugin_invalidation_factory): boolean; cdecl;
  end;


//entry.h

// This interface is the entry point of the dynamic library.
//
// CLAP plugins standard search path:
//
// Linux
//   - ~/.clap
//   - /usr/lib/clap
//
// Windows
//   - %COMMONPROGRAMFILES%\CLAP
//   - %LOCALAPPDATA%\Programs\Common\CLAP
//
// MacOS
//   - /Library/Audio/Plug-Ins/CLAP
//   - ~/Library/Audio/Plug-Ins/CLAP
//
// In addition to the OS-specific default locations above, a CLAP host must query the environment
// for a CLAP_PATH variable, which is a list of directories formatted in the same manner as the host
// OS binary search path (PATH on Unix, separated by `:` and Path on Windows, separated by ';', as
// of this writing).
//
// Each directory should be recursively searched for files and/or bundles as appropriate in your OS
// ending with the extension `.clap`.
//
// init and deinit in most cases are called once, in a matched pair, when the dso is loaded / unloaded.
// In some rare situations it may be called multiple times in a process, so the functions must be defensive,
// mutex locking and counting calls if undertaking non trivial non idempotent actions.
//
// Rationale:
//
//    The intent of the init() and deinit() functions is to provide a "normal" initialization patterh
//    which occurs when the shared object is loaded or unloaded. As such, hosts will call each once and
//    in matched pairs. In CLAP specifications prior to 1.2.0, this single-call was documented as a
//    requirement.
//
//    We realized, though, that this is not a requirement hosts can meet. If hosts load a plugin
//    which itself wraps another CLAP for instance, while also loading that same clap in its memory
//    space, both the host and the wrapper will call init() and deinit() and have no means to communicate
//    the state.
//
//    With CLAP 1.2.0 and beyond we are changing the spec to indicate that a host should make an
//    absolute best effort to call init() and deinit() once, and always in matched pairs (for every
//    init() which returns true, one deinit() should be called).
//
//    This takes the de-facto burden on plugin writers to deal with multiple calls into a hard requirement.
//
//    Most init() / deinit() pairs we have seen are the relatively trivial {return true;} and {}. But
//    if your init() function does non-trivial one time work, the plugin author must maintain a counter
//    and must manage a mutex lock. The most obvious implementation will maintain a static counter and a
//    global mutex, increment the counter on each init, decrement it on each deinit, and only undertake
//    the init or deinit action when the counter is zero.
  Tclap_plugin_entry = record
    clap_version: Tclap_version;     // initialized to CLAP_VERSION

    // Initializes the DSO.
    //
    // This function must be called first, before any-other CLAP-related function or symbol from this
    // DSO.
    //
    // It also must only be called once, until a later call to deinit() is made, after which init()
    // can be called once more to re-initialize the DSO.
    // This enables hosts to e.g. quickly load and unload a DSO for scanning its plugins, and then
    // load it again later to actually use the plugins if needed.
    //
    // As stated above, even though hosts are forbidden to do so directly, multiple calls before any
    // deinit() call may still happen. Implementations *should* take this into account, and *must*
    // do so as of CLAP 1.2.0.
    //
    // It should be as fast as possible, in order to perform a very quick scan of the plugin
    // descriptors.
    //
    // It is forbidden to display graphical user interfaces in this call.
    // It is forbidden to perform any user interaction in this call.
    //
    // If the initialization depends upon expensive computation, maybe try to do them ahead of time
    // and cache the result.
    //
    // Returns true on success. If init() returns false, then the DSO must be considered
    // uninitialized, and the host must not call deinit() nor any other CLAP-related symbols from the
    // DSO.
    // This function also returns true in the case where the DSO is already initialized, and no
    // actual initialization work is done in this call, as explain above.
    //
    // plugin_path is the path to the DSO (Linux, Windows), or the bundle (macOS).
    //
    // This function may be called on any thread, including a different one from the one a later call
    // to deinit() (or a later init()) can be made.
    // However, it is forbidden to call this function simultaneously from multiple threads.
    // It is also forbidden to call it simultaneously with *any* other CLAP-related symbols from the
    // DSO, including (but not limited to) deinit().
    //bool (*init)(const char *plugin_path);
    init: function (plugin_path: PAnsiChar): boolean; cdecl;

     // De-initializes the DSO, freeing any resources allocated or initialized by init().
     //
     // After this function is called, no more calls into the DSO must be made, except calling init()
     // again to re-initialize the DSO.
     // This means that after deinit() is called, the DSO can be considered to be in the same state
     // as if init() was never called at all yet, enabling it to be re-initialized as needed.
     //
     // As stated above, even though hosts are forbidden to do so directly, multiple calls before any
     // new init() call may still happen. Implementations *should* take this into account, and *must*
     // do so as of CLAP 1.2.0.
     //
     // Just like init(), this function may be called on any thread, including a different one from
     // the one init() was called from, or from the one a later init() call can be made.
     // However, it is forbidden to call this function simultaneously from multiple threads.
     // It is also forbidden to call it simultaneously with *any* other CLAP-related symbols from the
     // DSO, including (but not limited to) deinit().
    //void (*deinit)(void);
    deinit: procedure; cdecl;

    // Get the pointer to a factory. See factory/plugin-factory.h for an example.
    //
    // Returns null if the factory is not provided.
    // The returned pointer must *not* be freed by the caller.
    //
    // Unlike init() and deinit(), this function can be called simultaneously by multiple threads.
    //
    // [thread-safe]
    //const void *(*get_factory)(const char *factory_id);
    get_factory: function(factory_id: PAnsiChar): pointer; cdecl;
  end;
  Pclap_plugin_entry = ^Tclap_plugin_entry;

// Entry point
const
  clap_entry = 'clap_entry';


//stream.h

/// @page Streams
///
/// ## Notes on using streams
///
/// When working with `clap_istream` and `clap_ostream` objects to load and save
/// state, it is important to keep in mind that the host may limit the number of
/// bytes that can be read or written at a time. The return values for the
/// stream read and write functions indicate how many bytes were actually read
/// or written. You need to use a loop to ensure that you read or write the
/// entirety of your state. Don't forget to also consider the negative return
/// values for the end of file and IO error codes.

type
  Pclap_istream = ^Tclap_istream;
  Tclap_istream = record
    ctx: TObject; // reserved pointer for the stream

    // returns the number of bytes read; 0 indicates end of file and -1 a read error
    //int64_t (*read)(const struct clap_istream *stream, void *buffer, uint64_t size);
    read: function(stream: Pclap_istream; buffer: pointer; size: uint64_t): int64_t; cdecl;
  end;

  Pclap_ostream = ^Tclap_ostream;
  Tclap_ostream = record
    ctx: TObject; // reserved pointer for the stream

    // returns the number of bytes written; -1 on write error
    //int64_t (*write)(const struct clap_ostream *stream, const void *buffer, uint64_t size);
    write: function(stream: Pclap_ostream; buffer: pointer; size: uint64_t): int64_t; cdecl;
  end;


//timestamp.h

// This type defines a timestamp: the number of seconds since UNIX EPOCH.
// See C's time_t time(time_t *).
type
  Tclap_timestamp = uint64_t;

// Value for unknown timestamp.
const
  CLAP_TIMESTAMP_UNKNOWN = 0;



//ext\gui.h

/// @page GUI
///
/// This extension defines how the plugin will present its GUI.
///
/// There are two approaches:
/// 1. the plugin creates a window and embeds it into the host's window
/// 2. the plugin creates a floating window
///
/// Embedding the window gives more control to the host, and feels more integrated.
/// Floating window are sometimes the only option due to technical limitations.
///
/// The Embedding protocol is by far the most common, supported by all hosts to date,
/// and a plugin author should support at least that case.
///
/// Showing the GUI works as follow:
///  1. clap_plugin_gui->is_api_supported(), check what can work
///  2. clap_plugin_gui->create(), allocates gui resources
///  3. if the plugin window is floating
///  4.    -> clap_plugin_gui->set_transient()
///  5.    -> clap_plugin_gui->suggest_title()
///  6. else
///  7.    -> clap_plugin_gui->set_scale()
///  8.    -> clap_plugin_gui->can_resize()
///  9.    -> if resizable and has known size from previous session, clap_plugin_gui->set_size()
/// 10.    -> else clap_plugin_gui->get_size(), gets initial size
/// 11.    -> clap_plugin_gui->set_parent()
/// 12. clap_plugin_gui->show()
/// 13. clap_plugin_gui->hide()/show() ...
/// 14. clap_plugin_gui->destroy() when done with the gui
///
/// Resizing the window (initiated by the plugin, if embedded):
/// 1. Plugins calls clap_host_gui->request_resize()
/// 2. If the host returns true the new size is accepted,
///    the host doesn't have to call clap_plugin_gui->set_size().
///    If the host returns false, the new size is rejected.
///
/// Resizing the window (drag, if embedded)):
/// 1. Only possible if clap_plugin_gui->can_resize() returns true
/// 2. Mouse drag -> new_size
/// 3. clap_plugin_gui->adjust_size(new_size) -> working_size
/// 4. clap_plugin_gui->set_size(working_size)

const
  CLAP_EXT_GUI = AnsiString('clap.gui');

// If your windowing API is not listed here, please open an issue and we'll figure it out.
// https://github.com/free-audio/clap/issues/new

// uses physical size
// embed using https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setparent
  CLAP_WINDOW_API_WIN32 = AnsiString('win32');

// uses logical size, don't call clap_plugin_gui->set_scale()
  CLAP_WINDOW_API_COCOA = AnsiString('cocoa');

// uses physical size
// embed using https://specifications.freedesktop.org/xembed-spec/xembed-spec-latest.html
  CLAP_WINDOW_API_X11 = AnsiString('x11');

// uses physical size
// embed is currently not supported, use floating windows
  CLAP_WINDOW_API_WAYLAND = AnsiString('wayland');

type
  Tclap_hwnd = pointer;
  Tclap_nsview = pointer;
  Tclap_xwnd = UInt32;

// Represent a window reference.
  Tclap_window = record
    api: PAnsiChar; // one of CLAP_WINDOW_API_XXX
    case integer of
    0:(cocoa: Tclap_nsview);
    1:(x11: Tclap_xwnd);
    2:(win32: Tclap_hwnd);
    3:(ptr: pointer); // for anything defined outside of clap
  end;
  Pclap_window = ^Tclap_window;

// Information to improve window resizing when initiated by the host or window manager.
  Tclap_gui_resize_hints = record
    can_resize_horizontally: boolean;
    can_resize_vertically: boolean;
    // if both horizontal and vertical resize are available, do we preserve the
    // aspect ratio, and if so, what is the width x height aspect ratio to preserve.
    // These flags are unused if can_resize_horizontally or vertically are false,
    // and ratios are unused if preserve is false.
    preseve_aspect_ratio: boolean;
    aspect_ratio_width: uint32_t;
    aspect_ratio_height: uint32_t;
  end;

// Size (width, height) is in pixels; the corresponding windowing system extension is
// responsible for defining if it is physical pixels or logical pixels.
  Tclap_plugin_gui = record
    // Returns true if the requested gui api is supported, either in floating (plugin-created)
    // or non-floating (embedded) mode.
    // [main-thread]
    //bool (*is_api_supported)(const clap_plugin_t *plugin, const char *api, bool is_floating);
    is_api_supported: function(plugin: Pclap_plugin; api: PAnsiChar; is_floating: boolean): boolean; cdecl;

    // Returns true if the plugin has a preferred api.
    // The host has no obligation to honor the plugin preference, this is just a hint.
    // The const char **api variable should be explicitly assigned as a pointer to
    // one of the CLAP_WINDOW_API_ constants defined above, not strcopied.
    // [main-thread]
    //bool (*get_preferred_api)(const clap_plugin_t *plugin, const char **api, bool *is_floating);
    get_preferred_api: function(plugin: Pclap_plugin; var api: PAnsiChar; var is_floating: boolean): boolean; cdecl;

    // Create and allocate all resources necessary for the gui.
    //
    // If is_floating is true, then the window will not be managed by the host. The plugin
    // can set its window to stays above the parent window, see set_transient().
    // api may be null or blank for floating window.
    //
    // If is_floating is false, then the plugin has to embed its window into the parent window, see
    // set_parent().
    //
    // After this call, the GUI may not be visible yet; don't forget to call show().
    //
    // Returns true if the GUI is successfully created.
    // [main-thread]
    //bool (*create)(const clap_plugin_t *plugin, const char *api, bool is_floating);
    create: function(plugin: Pclap_plugin; api: PAnsiChar; is_floating: boolean): boolean; cdecl;

    // Free all resources associated with the gui.
    // [main-thread]
    //void (*destroy)(const clap_plugin_t *plugin);
    destroy: procedure(plugin: Pclap_plugin); cdecl;

    // Set the absolute GUI scaling factor, and override any OS info.
    // Should not be used if the windowing api relies upon logical pixels.
    //
    // If the plugin prefers to work out the scaling factor itself by querying the OS directly,
    // then ignore the call.
    //
    // scale = 2 means 200% scaling.
    //
    // Returns true if the scaling could be applied
    // Returns false if the call was ignored, or the scaling could not be applied.
    // [main-thread]
    //bool (*set_scale)(const clap_plugin_t *plugin, double scale);
    set_scale: function(plugin: Pclap_plugin; scale: double): boolean; cdecl;

    // Get the current size of the plugin UI.
    // clap_plugin_gui->create() must have been called prior to asking the size.
    //
    // Returns true if the plugin could get the size.
    // [main-thread]
    //bool (*get_size)(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height);
    get_size: function(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;

    // Returns true if the window is resizeable (mouse drag).
    // [main-thread & !floating]
    //bool (*can_resize)(const clap_plugin_t *plugin);
    can_resize: function(plugin: Pclap_plugin): boolean; cdecl;

    // Returns true if the plugin can provide hints on how to resize the window.
    // [main-thread & !floating]
    //bool (*get_resize_hints)(const clap_plugin_t *plugin, clap_gui_resize_hints_t *hints);
    get_resize_hints: function(plugin: Pclap_plugin; var hints: Tclap_gui_resize_hints): boolean; cdecl;

    // If the plugin gui is resizable, then the plugin will calculate the closest
    // usable size which fits in the given size.
    // This method does not change the size.
    //
    // Returns true if the plugin could adjust the given size.
    // [main-thread & !floating]
    //bool (*adjust_size)(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height);
    adjust_size: function(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;

    // Sets the window size. Only for embedded windows.
    //
    // Returns true if the plugin could resize its window to the given size.
    // [main-thread & !floating]
    //bool (*set_size)(const clap_plugin_t *plugin, uint32_t width, uint32_t height);
    set_size: function(plugin: Pclap_plugin; width: uint32_t; height: uint32_t): boolean; cdecl;

    // Embbeds the plugin window into the given window.
    //
    // Returns true on success.
    // [main-thread & !floating]
    //bool (*set_parent)(const clap_plugin_t *plugin, const clap_window_t *window);
    set_parent: function(plugin: Pclap_plugin; window: Pclap_window): boolean; cdecl;

    // Set the plugin floating window to stay above the given window.
    //
    // Returns true on success.
    // [main-thread & floating]
    //bool (*set_transient)(const clap_plugin_t *plugin, const clap_window_t *window);
    set_transient: function(plugin: Pclap_plugin; window: Pclap_window): boolean; cdecl;

    // Suggests a window title. Only for floating windows.
    //
    // [main-thread & floating]
    //void (*suggest_title)(const clap_plugin_t *plugin, const char *title);
    suggest_title: procedure(plugin: Pclap_plugin; title: PAnsiChar); cdecl;

    // Show the window.
    //
    // Returns true on success.
    // [main-thread]
    //bool (*show)(const clap_plugin_t *plugin);
    show: function(plugin: Pclap_plugin): boolean; cdecl;

    // Hide the window, this method does not free the resources, it just hides
    // the window content. Yet it may be a good idea to stop painting timers.
    //
    // Returns true on success.
    // [main-thread]
    //bool (*hide)(const clap_plugin_t *plugin);
    hide: function(plugin: Pclap_plugin): boolean; cdecl;
  end;
  Pclap_plugin_gui = ^Tclap_plugin_gui;

  clap_host_gui = record
    // The host should call get_resize_hints() again.
    // [thread-safe & !floating]
    //void (*resize_hints_changed)(const clap_host_t *host);
    resize_hints_changed: procedure(host: Pclap_host); cdecl;

    // Request the host to resize the client area to width, height.
    // Return true if the new size is accepted, false otherwise.
    // The host doesn't have to call set_size().
    //
    // Note: if not called from the main thread, then a return value simply means that the host
    // acknowledged the request and will process it asynchronously. If the request then can't be
    // satisfied then the host will call set_size() to revert the operation.
    //
    // [thread-safe & !floating] */
    //bool (*resize)(const clap_host_t *host, uint32_t width, uint32_t height);
    request_resize: function(host: Pclap_host; width: uint32_t; height: uint32_t): boolean; cdecl;

    // Request the host to show the plugin gui.
    // Return true on success, false otherwise.
    // [thread-safe] */
    //bool (*request_show)(const clap_host_t *host);
    request_show: function(host: Pclap_host): boolean; cdecl;

    // Request the host to hide the plugin gui.
    // Return true on success, false otherwise.
    // [thread-safe] */
    //bool (*request_hide)(const clap_host_t *host);
    request_hide: function(host: Pclap_host): boolean; cdecl;

    // The floating window has been closed, or the connection to the gui has been lost.
    //
    // If was_destroyed is true, then the host must call clap_plugin_gui->destroy() to acknowledge
    // the gui destruction.
    // [thread-safe] */
    //void (*closed)(const clap_host_t *host, bool was_destroyed);
    closed: procedure(host: Pclap_host; was_destroyed: boolean); cdecl;
  end;


//ext\log.h

const
  CLAP_EXT_LOG = AnsiString('clap.log');

  CLAP_LOG_DEBUG = 0;
  CLAP_LOG_INFO = 1;
  CLAP_LOG_WARNING = 2;
  CLAP_LOG_ERROR = 3;
  CLAP_LOG_FATAL = 4;

  // These severities should be used to report misbehaviour.
  // The plugin one can be used by a layer between the plugin and the host.
  CLAP_LOG_HOST_MISBEHAVING = 5;
  CLAP_LOG_PLUGIN_MISBEHAVING = 6;

type
  Tclap_log_severity = int32_t;

  Tclap_host_log = record
    // Log a message through the host.
    // [thread-safe]
    //void (*log)(const clap_host_t *host, clap_log_severity severity, const char *msg);
    log: procedure(host: Pclap_host; severity: Tclap_log_severity; msg: PAnsiChar); cdecl;
  end;
  Pclap_host_log = ^Tclap_host_log;


//ext\state.h

/// @page State
/// @brief state management
///
/// Plugins can implement this extension to save and restore both parameter
/// values and non-parameter state. This is used to persist a plugin's state
/// between project reloads, when duplicating and copying plugin instances, and
/// for host-side preset management.
///
/// If you need to know if the save/load operation is meant for duplicating a plugin
/// instance, for saving/loading a plugin preset or while saving/loading the project
/// then consider implementing CLAP_EXT_STATE_CONTEXT in addition to CLAP_EXT_STATE.

const
  CLAP_EXT_STATE = AnsiString('clap.state');

type
  Tclap_plugin_state = record
    // Saves the plugin state into stream.
    // Returns true if the state was correctly saved.
    // [main-thread]
    //bool (*save)(const clap_plugin_t *plugin, const clap_ostream_t *stream);
    save: function(plugin: Pclap_plugin; stream: Pclap_ostream): boolean; cdecl;

    // Loads the plugin state from stream.
    // Returns true if the state was correctly restored.
    // [main-thread]
    //bool (*load)(const clap_plugin_t *plugin, const clap_istream_t *stream);
    load: function(plugin: Pclap_plugin; stream: Pclap_istream): boolean; cdecl;
  end;
  Pclap_plugin_state = ^Tclap_plugin_state;

  Tclap_host_state = record
    // Tell the host that the plugin state has changed and should be saved again.
    // If a parameter value changes, then it is implicit that the state is dirty.
    // [main-thread]
    //void (*mark_dirty)(const clap_host_t *host);
    mark_dirty: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_state = ^Tclap_host_state;


//ext\state-context.h

/// @page state-context extension
/// @brief extended state handling
///
/// This extension lets the host save and load the plugin state with different semantics depending
/// on the context.
///
/// Briefly, when loading a preset or duplicating a device, the plugin may want to partially load
/// the state and initialize certain things differently, like handling limited resources or fixed
/// connections to external hardware resources.
///
/// Save and Load operations may have a different context.
/// All three operations should be equivalent:
/// 1. clap_plugin_state_context.load(clap_plugin_state.save(), CLAP_STATE_CONTEXT_FOR_PRESET)
/// 2. clap_plugin_state.load(clap_plugin_state_context.save(CLAP_STATE_CONTEXT_FOR_PRESET))
/// 3. clap_plugin_state_context.load(
///        clap_plugin_state_context.save(CLAP_STATE_CONTEXT_FOR_PRESET),
///        CLAP_STATE_CONTEXT_FOR_PRESET)
///
/// If in doubt, fallback to clap_plugin_state.
///
/// If the plugin implements CLAP_EXT_STATE_CONTEXT then it is mandatory to also implement
/// CLAP_EXT_STATE.
///
/// It is unspecified which context is equivalent to clap_plugin_state.{save,load}()

const
  CLAP_EXT_STATE_CONTEXT = AnsiString('clap.state-context/2');

  // suitable for storing and loading a state as a preset
  CLAP_STATE_CONTEXT_FOR_PRESET = 1;

  // suitable for duplicating a plugin instance
  CLAP_STATE_CONTEXT_FOR_DUPLICATE = 2;

  // suitable for storing and loading a state within a project/song
  CLAP_STATE_CONTEXT_FOR_PROJECT = 3;

type
  Tclap_plugin_state_context = record
    // Saves the plugin state into stream, according to context_type.
    // Returns true if the state was correctly saved.
    //
    // Note that the result may be loaded by both clap_plugin_state.load() and
    // clap_plugin_state_context.load().
    // [main-thread]
    //bool (*save)(const clap_plugin_t *plugin, const clap_ostream_t *stream, uint32_t context_type);
    save: function(plugin: Pclap_plugin; stream: Pclap_ostream; context_type: uint32_t): boolean; cdecl;

    // Loads the plugin state from stream, according to context_type.
    // Returns true if the state was correctly restored.
    //
    // Note that the state may have been saved by clap_plugin_state.save() or
    // clap_plugin_state_context.save() with a different context_type.
    // [main-thread]
    //bool (*load)(const clap_plugin_t *plugin, const clap_istream_t *stream, uint32_t context_type);
    load: function(plugin: Pclap_plugin; stream: Pclap_istream; context_type: uint32_t): boolean; cdecl;
  end;
  Pclap_plugin_state_context = ^Tclap_plugin_state_context;


//ext\timer-support.h

const
  CLAP_EXT_TIMER_SUPPORT = AnsiString('clap.timer-support');

type
  Tclap_plugin_timer_support = record
    // [main-thread]
    //void (*on_timer)(const clap_plugin_t *plugin, clap_id timer_id);
    on_timer: procedure(plugin: Pclap_plugin; timer_id: Tclap_id); cdecl;
  end;
  Pclap_plugin_timer_support = ^Tclap_plugin_timer_support;

  Tclap_host_timer_support = record
    // Registers a periodic timer.
    // The host may adjust the period if it is under a certain threshold.
    // 30 Hz should be allowed.
    // Returns true on success.
    // [main-thread]
    //bool (*register_timer)(const clap_host_t *host, uint32_t period_ms, clap_id *timer_id);
    register_timer: function(host: Pclap_host; period_ms: uint32_t; var timer_id: Tclap_id): boolean; cdecl;

    // Returns true on success.
    // [main-thread]
    //bool (*unregister_timer)(const clap_host_t *host, clap_id timer_id);
    unregister_timer: function(host: Pclap_host; timer_id: Tclap_id): boolean; cdecl;
  end;


//ext\audio-ports.h

/// @page Audio Ports
///
/// This extension provides a way for the plugin to describe its current audio ports.
///
/// If the plugin does not implement this extension, it won't have audio ports.
///
/// 32 bits support is required for both host and plugins. 64 bits audio is optional.
///
/// The plugin is only allowed to change its ports configuration while it is deactivated.

const
  CLAP_EXT_AUDIO_PORTS = AnsiString('clap.audio-ports');
  CLAP_PORT_MONO = AnsiString('mono');
  CLAP_PORT_STEREO = AnsiString('stereo');

  // This port is the main audio input or output.
  // There can be only one main input and main output.
  // Main port must be at index 0.
  CLAP_AUDIO_PORT_IS_MAIN = 1 shl 0;

  // This port can be used with 64 bits audio
  CLAP_AUDIO_PORT_SUPPORTS_64BITS = 1 shl 1;

  // 64 bits audio is preferred with this port
  CLAP_AUDIO_PORTS_PREFERS_64BITS = 1 shl 2;

  // This port must be used with the same sample size as all the other ports which have this flag.
  // In other words if all ports have this flag then the plugin may either be used entirely with
  // 64 bits audio or 32 bits audio, but it can't be mixed.
  CLAP_AUDIO_PORT_REQUIRES_COMMON_SAMPLE_SIZE = 1 shl 3;

type
  Tclap_audio_port_info = record
    // id identifies a port and must be stable.
    // id may overlap between input and output ports.
    id: Tclap_id;
    name: array[0..CLAP_NAME_SIZE - 1] of byte; // displayable name

    flags: uint32_t;
    channel_count: uint32_t;

    // If null or empty then it is unspecified (arbitrary audio).
    // This field can be compared against:
    // - CLAP_PORT_MONO
    // - CLAP_PORT_STEREO
    // - CLAP_PORT_SURROUND (defined in the surround extension)
    // - CLAP_PORT_AMBISONIC (defined in the ambisonic extension)
    //
    // An extension can provide its own port type and way to inspect the channels.
    port_type: PAnsiChar;

    // in-place processing: allow the host to use the same buffer for input and output
    // if supported set the pair port id.
    // if not supported set to CLAP_INVALID_ID
    in_place_pair: Tclap_id;
  end;
  Pclap_audio_port_info = ^Tclap_audio_port_info;

// The audio ports scan has to be done while the plugin is deactivated.
  Tclap_plugin_audio_ports = record
    // Number of ports, for either input or output
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin, bool is_input);
    count: function(plugin: Pclap_plugin; is_input: boolean): uint32_t; cdecl;

    // Get info about an audio port.
    // Returns true on success and stores the result into info.
    // [main-thread]
    //bool (*get)(const clap_plugin_t    *plugin,
    //           uint32_t                index,
    //           bool                    is_input,
    //           clap_audio_port_info_t *info);
    get: function(plugin: Pclap_plugin; index: uint32_t; is_input: boolean; var info: Tclap_audio_port_info): boolean; cdecl;
  end;
  Pclap_plugin_audio_ports = ^Tclap_plugin_audio_ports;

const
  // The ports name did change, the host can scan them right away.
  CLAP_AUDIO_PORTS_RESCAN_NAMES = 1 shl 0;

  // [!active] The flags did change
  CLAP_AUDIO_PORTS_RESCAN_FLAGS = 1 shl 1;

  // [!active] The channel_count did change
  CLAP_AUDIO_PORTS_RESCAN_CHANNEL_COUNT = 1 shl 2;

  // [!active] The port type did change
  CLAP_AUDIO_PORTS_RESCAN_PORT_TYPE = 1 shl 3;

  // [!active] The in-place pair did change, this requires.
  CLAP_AUDIO_PORTS_RESCAN_IN_PLACE_PAIR = 1 shl 4;

  // [!active] The list of ports have changed: entries have been removed/added.
  CLAP_AUDIO_PORTS_RESCAN_LIST = 1 shl 5;

type
  Tclap_host_audio_ports = record
    // Checks if the host allows a plugin to change a given aspect of the audio ports definition.
    // [main-thread]
    //bool (*is_rescan_flag_supported)(const clap_host_t *host, uint32_t flag);
    is_rescan_flag_supported: function(host: Pclap_host; flag: uint32_t): boolean;

    // Rescan the full list of audio ports according to the flags.
    // It is illegal to ask the host to rescan with a flag that is not supported.
    // Certain flags require the plugin to be de-activated.
    // [main-thread,!active]
    //void (*rescan)(const clap_host_t *host, uint32_t flags);
    rescan: procedure(host: Pclap_host; flags: uint32_t); cdecl;
  end;


//ext\audio-ports-config.h

/// @page Audio Ports Config
///
/// This extension let the plugin provide port configurations presets.
/// For example mono, stereo, surround, ambisonic, ...
///
/// After the plugin initialization, the host may scan the list of configurations and eventually
/// select one that fits the plugin context. The host can only select a configuration if the plugin
/// is deactivated.
///
/// A configuration is a very simple description of the audio ports:
/// - it describes the main input and output ports
/// - it has a name that can be displayed to the user
///
/// The idea behind the configurations, is to let the user choose one via a menu.
///
/// Plugins with very complex configuration possibilities should let the user configure the ports
/// from the plugin GUI, and call @ref clap_host_audio_ports.rescan(CLAP_AUDIO_PORTS_RESCAN_ALL).
///
/// To inquire the exact bus layout, the plugin implements the clap_plugin_audio_ports_config_info_t
/// extension where all busses can be retrieved in the same way as in the audio-port extension.
const
  CLAP_EXT_AUDIO_PORTS_CONFIG = AnsiString('clap.audio-ports-config');
  CLAP_EXT_AUDIO_PORTS_CONFIG_INFO = AnsiString('clap.audio-ports-config-info/1');

// The latest draft is 100% compatible.
// This compat ID may be removed in 2026.
  CLAP_EXT_AUDIO_PORTS_CONFIG_INFO_COMPAT = AnsiString('clap.audio-ports-config-info/draft-0');

// Minimalistic description of ports configuration
type
  Tclap_audio_ports_config = record
    id: Tclap_id;
    name: array[0..CLAP_NAME_SIZE - 1] of byte;
    input_port_count: uint32_t;
    output_port_count: uint32_t;
    // main input info
    has_main_input: boolean;
    main_input_channel_count: uint32_t;
    main_input_port_type: PAnsiChar;
    // main output info
    has_main_output: boolean;
    main_output_channel_count: uint32_t;
    main_output_port_type: PAnsiChar;
  end;
  Pclap_audio_ports_config = ^Tclap_audio_ports_config;

// The audio ports config scan has to be done while the plugin is deactivated.
  Tclap_plugin_audio_ports_config = record
    // Gets the number of available configurations
    // [main-thread]
    //uint32_t(CLAP_ABI *count)(const clap_plugin_t *plugin);
    count: function(plugin: Pclap_plugin): uint32_t; cdecl;

    // Gets information about a configuration
    // Returns true on success and stores the result into config.
    // [main-thread]
    //bool(CLAP_ABI *get)(const clap_plugin_t       *plugin,
    //                   uint32_t                   index,
    //                   clap_audio_ports_config_t *config);
    get: function(plugin: Pclap_plugin; index: uint32_t; config: Pclap_audio_ports_config): boolean; cdecl;

    // selects the configuration designated by id
    // returns true if the configuration could be applied
    // Once applied the host should scan again the audio ports.
    // [main-thread,plugin-deactivated]
    //bool(CLAP_ABI *select)(const clap_plugin_t *plugin, clap_id config_id);
    select: function(plugin: Pclap_plugin; config_id: Tclap_id): boolean; cdecl;
  end;
  Pclap_plugin_audio_ports_config = ^Tclap_plugin_audio_ports_config;

// Extended config info
  Tclap_plugin_audio_ports_config_info = record
    // Gets the id of the currently selected config, or CLAP_INVALID_ID if the current port
    // layout isn't part of the config list.
    //
    // [main-thread]
    //clap_id(CLAP_ABI *current_config)(const clap_plugin_t *plugin);
    current_config: function(plugin: Pclap_plugin): Tclap_id; cdecl;
    // Get info about an audio port, for a given config_id.
    // This is analogous to clap_plugin_audio_ports.get().
    // Returns true on success and stores the result into info.
    // [main-thread]
    //bool(CLAP_ABI *get)(const clap_plugin_t    *plugin,
    //                    clap_id                 config_id,
    //                    uint32_t                port_index,
    //                    bool                    is_input,
    //                    clap_audio_port_info_t *info);
    get: function(plugin: Pclap_plugin; config_id: Tclap_id; port_index: uint32_t; is_input: boolean; info: Pclap_audio_port_info): boolean; cdecl;
  end;

  Tclap_host_audio_ports_config = record
    // Rescan the full list of configs.
    // [main-thread]
    //void(CLAP_ABI *rescan)(const clap_host_t *host);
    rescan: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_audio_ports_config = ^Tclap_host_audio_ports_config;

//ext\configurable-audio-ports.h

// This extension lets the host configure the plugin's input and output audio ports
// This is a "push" approach to audio ports configuration.
const
  CLAP_EXT_CONFIGURABLE_AUDIO_PORTS = AnsiString('clap.configurable-audio-ports/1');

  // The latest draft is 100% compatible.
  // This compat ID may be removed in 2026.
  CLAP_EXT_CONFIGURABLE_AUDIO_PORTS_COMPAT = AnsiString('clap.configurable-audio-ports.draft1');

type
  Tclap_audio_port_configuration_request = record
    // Identifies the port by is_input and port_index
    is_input: boolean;
    port_index: uint32_t;

    // The requested number of channels.
    channel_count: uint32_t;

    // The port type, see audio-ports.h, clap_audio_port_info.port_type for interpretation.
    port_type: PAnsiChar;

    // cast port_details according to port_type:
    // - CLAP_PORT_MONO: (discard)
    // - CLAP_PORT_STEREO: (discard)
    // - CLAP_PORT_SURROUND: const uint8_t *channel_map
    // - CLAP_PORT_AMBISONIC: const clap_ambisonic_config_t *info
    port_details: pointer;
  end;
  Pclap_audio_port_configuration_request = ^Tclap_audio_port_configuration_request;

  Tclap_plugin_configurable_audio_ports = record
    // Returns true if the given configurations can be applied using apply_configuration().
    // [main-thread && !active]
    //bool(CLAP_ABI *can_apply_configuration)(
    //     const clap_plugin_t                                *plugin,
    //     const struct clap_audio_port_configuration_request *requests,
    //     uint32_t                                            request_count);
    can_apply_configuration: function(plugin: Pclap_plugin; requests: Pclap_audio_port_configuration_request; request_count: uint32_t): boolean; cdecl;

    // Submit a bunch of configuration requests which will atomically be applied together,
    // or discarded together.
    //
    // Once the configuration is successfully applied, it isn't necessary for the plugin to call
    // clap_host_audio_ports->changed(); and it isn't necessary for the host to scan the
    // audio ports.
    //
    // Returns true if applied.
    // [main-thread && !active]
    //bool(CLAP_ABI *apply_configuration)(const clap_plugin_t                                *plugin,
    //                                    const struct clap_audio_port_configuration_request *requests,
    //                                    uint32_t request_count);
    apply_configuration: function(plugin: Pclap_plugin; requests: Pclap_audio_port_configuration_request; request_count: uint32_t): boolean; cdecl;
  end;
  Pclap_plugin_configurable_audio_ports = ^Tclap_plugin_configurable_audio_ports;


//ext\note-ports.h

/// @page Note Ports
///
/// This extension provides a way for the plugin to describe its current note ports.
/// If the plugin does not implement this extension, it won't have note input or output.
/// The plugin is only allowed to change its note ports configuration while it is deactivated.

const
  CLAP_EXT_NOTE_PORTS = AnsiString('clap.note-ports');

   // Uses clap_event_note and clap_event_note_expression.
  CLAP_NOTE_DIALECT_CLAP = 1 shl 0;

   // Uses clap_event_midi, no polyphonic expression
  CLAP_NOTE_DIALECT_MIDI = 1 shl 1;

   // Uses clap_event_midi, with polyphonic expression (MPE)
  CLAP_NOTE_DIALECT_MIDI_MPE = 1 shl 2;

   // Uses clap_event_midi2
  CLAP_NOTE_DIALECT_MIDI2 = 1 shl 3;

type
  Tclap_note_port_info = record
    // id identifies a port and must be stable.
    // id may overlap between input and output ports.
    id: Tclap_id;
    supported_dialects: uint32_t; // bitfield, see clap_note_dialect
    preferred_dialect: uint32_t;  // one value of clap_note_dialect
    name: array[0..CLAP_NAME_SIZE - 1] of byte; // displayable name, i18n?
  end;

// The note ports scan has to be done while the plugin is deactivated.
  Tclap_plugin_note_ports = record
    // Number of ports, for either input or output
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin, bool is_input);
    count: function(plugin: Pclap_plugin; is_input: boolean): uint32_t; cdecl;

    // Get info about a note port.
    // Returns true on success and stores the result into info.
    // [main-thread]
    //bool (*get)(const clap_plugin_t   *plugin,
    //            uint32_t               index,
    //            bool                   is_input,
    //            clap_note_port_info_t *info);
    get: function(plugin: Pclap_plugin; index: uint32_t; is_input: boolean; var info: Tclap_note_port_info): boolean; cdecl;
  end;
  Pclap_plugin_note_ports = ^Tclap_plugin_note_ports;

const
  // The ports have changed, the host shall perform a full scan of the ports.
  // This flag can only be used if the plugin is not active.
  // If the plugin active, call host->request_restart() and then call rescan()
  // when the host calls deactivate()
  CLAP_NOTE_PORTS_RESCAN_ALL = 1 shl 0;

  // The ports name did change, the host can scan them right away.
  CLAP_NOTE_PORTS_RESCAN_NAMES = 1 shl 1;

type
  Tclap_host_note_ports = record
    // Query which dialects the host supports
    // [main-thread]
    //uint32_t (*supported_dialects)(const clap_host_t *host);
    supported_dialects: function(host: Pclap_host): uint32_t; cdecl;

    // Rescan the full list of note ports according to the flags.
    // [main-thread]
    //void (*rescan)(const clap_host_t *host, uint32_t flags);
    rescan: procedure(host: Pclap_host; flags: uint32_t); cdecl;
  end;
  Pclap_host_note_ports = ^Tclap_host_note_ports;


//ext\params.h

/// @page Parameters
/// @brief parameters management
///
/// Main idea:
///
/// The host sees the plugin as an atomic entity; and acts as a controller on top of its parameters.
/// The plugin is responsible for keeping its audio processor and its GUI in sync.
///
/// The host can at any time read parameters' value on the [main-thread] using
/// @ref clap_plugin_params.get_value().
///
/// There are two options to communicate parameter value changes, and they are not concurrent.
/// - send automation points during clap_plugin.process()
/// - send automation points during clap_plugin_params.flush(), for parameter changes
///   without processing audio
///
/// When the plugin changes a parameter value, it must inform the host.
/// It will send @ref CLAP_EVENT_PARAM_VALUE event during process() or flush().
/// If the user is adjusting the value, don't forget to mark the beginning and end
/// of the gesture by sending CLAP_EVENT_PARAM_GESTURE_BEGIN and CLAP_EVENT_PARAM_GESTURE_END
/// events.
///
/// @note MIDI CCs are tricky because you may not know when the parameter adjustment ends.
/// Also if the host records incoming MIDI CC and parameter change automation at the same time,
/// there will be a conflict at playback: MIDI CC vs Automation.
/// The parameter automation will always target the same parameter because the param_id is stable.
/// The MIDI CC may have a different mapping in the future and may result in a different playback.
///
/// When a MIDI CC changes a parameter's value, set the flag CLAP_EVENT_DONT_RECORD in
/// clap_event_param.header.flags. That way the host may record the MIDI CC automation, but not the
/// parameter change and there won't be conflict at playback.
///
/// Scenarios:
///
/// I. Loading a preset
/// - load the preset in a temporary state
/// - call @ref clap_host_params.rescan() if anything changed
/// - call @ref clap_host_latency.changed() if latency changed
/// - invalidate any other info that may be cached by the host
/// - if the plugin is activated and the preset will introduce breaking changes
///   (latency, audio ports, new parameters, ...) be sure to wait for the host
///   to deactivate the plugin to apply those changes.
///   If there are no breaking changes, the plugin can apply them them right away.
///   The plugin is responsible for updating both its audio processor and its gui.
///
/// II. Turning a knob on the DAW interface
/// - the host will send an automation event to the plugin via a process() or flush()
///
/// III. Turning a knob on the Plugin interface
/// - the plugin is responsible for sending the parameter value to its audio processor
/// - call clap_host_params->request_flush() or clap_host->request_process().
/// - when the host calls either clap_plugin->process() or clap_plugin_params->flush(),
///   send an automation event and don't forget to wrap the parameter change(s)
///   with CLAP_EVENT_PARAM_GESTURE_BEGIN and CLAP_EVENT_PARAM_GESTURE_END to define the
///   beginning and end of the gesture.
///
/// IV. Turning a knob via automation
/// - host sends an automation point during clap_plugin->process() or clap_plugin_params->flush().
/// - the plugin is responsible for updating its GUI
///
/// V. Turning a knob via plugin's internal MIDI mapping
/// - the plugin sends a CLAP_EVENT_PARAM_VALUE output event, set should_record to false
/// - the plugin is responsible for updating its GUI
///
/// VI. Adding or removing parameters
/// - if the plugin is activated call clap_host->restart()
/// - once the plugin isn't active:
///   - apply the new state
///   - if a parameter is gone or is created with an id that may have been used before,
///     call clap_host_params.clear(host, param_id, CLAP_PARAM_CLEAR_ALL)
///   - call clap_host_params->rescan(CLAP_PARAM_RESCAN_ALL)
///
/// CLAP allows the plugin to change the parameter range, yet the plugin developer
/// should be aware that doing so isn't without risk, especially if you made the
/// promise to never change the sound. If you want to be 100% certain that the
/// sound will not change with all host, then simply never change the range.
///
/// There are two approaches to automations, either you automate the plain value,
/// or you automate the knob position. The first option will be robust to a range
/// increase, while the second won't be.
///
/// If the host goes with the second approach (automating the knob position), it means
/// that the plugin is hosted in a relaxed environment regarding sound changes (they are
/// accepted, and not a concern as long as they are reasonable). Though, stepped parameters
/// should be stored as plain value in the document.
///
/// If the host goes with the first approach, there will still be situation where the
/// sound may inevitably change. For example, if the plugin increase the range, there
/// is an automation playing at the max value and on top of that an LFO is applied.
/// See the following curve:
///                                   .
///                                  . .
///          .....                  .   .
/// before: .     .     and after: .     .
///
/// Persisting parameter values:
///
/// Plugins are responsible for persisting their parameter's values between
/// sessions by implementing the state extension. Otherwise parameter value will
/// not be recalled when reloading a project. Hosts should _not_ try to save and
/// restore parameter values for plugins that don't implement the state
/// extension.
///
/// Advice for the host:
///
/// - store plain values in the document (automation)
/// - store modulation amount in plain value delta, not in percentage
/// - when you apply a CC mapping, remember the min/max plain values so you can adjust
/// - do not implement a parameter saving fall back for plugins that don't
///   implement the state extension
///
/// Advice for the plugin:
///
/// - think carefully about your parameter range when designing your DSP
/// - avoid shrinking parameter ranges, they are very likely to change the sound
/// - consider changing the parameter range as a tradeoff: what you improve vs what you break
/// - make sure to implement saving and loading the parameter values using the
///   state extension
/// - if you plan to use adapters for other plugin formats, then you need to pay extra
///   attention to the adapter requirements

const
  CLAP_EXT_PARAMS = AnsiString('clap.params');

  // Is this param stepped? (integer values only)
  // if so the double value is converted to integer using a cast (equivalent to trunc).
  CLAP_PARAM_IS_STEPPED = 1 shl 0;

  // Useful for periodic parameters like a phase
  CLAP_PARAM_IS_PERIODIC = 1 shl 1;

  // The parameter should not be shown to the user, because it is currently not used.
  // It is not necessary to process automation for this parameter.
  CLAP_PARAM_IS_HIDDEN = 1 shl 2;

  // The parameter can't be changed by the host.
  CLAP_PARAM_IS_READONLY = 1 shl 3;

  // This parameter is used to merge the plugin and host bypass button.
  // It implies that the parameter is stepped.
  // min: 0 -> bypass off
  // max: 1 -> bypass on
  CLAP_PARAM_IS_BYPASS = 1 shl 4;

  // When set:
  // - automation can be recorded
  // - automation can be played back
  //
  // The host can send live user changes for this parameter regardless of this flag.
  //
  // If this parameter affects the internal processing structure of the plugin, ie: max delay, fft
  // size, ... and the plugins needs to re-allocate its working buffers, then it should call
  // host->request_restart(), and perform the change once the plugin is re-activated.
  CLAP_PARAM_IS_AUTOMATABLE = 1 shl 5;

  // Does this parameter support per note automations?
  CLAP_PARAM_IS_AUTOMATABLE_PER_NOTE_ID = 1 shl 6;

  // Does this parameter support per key automations?
  CLAP_PARAM_IS_AUTOMATABLE_PER_KEY = 1 shl 7;

  // Does this parameter support per channel automations?
  CLAP_PARAM_IS_AUTOMATABLE_PER_CHANNEL = 1 shl 8;

  // Does this parameter support per port automations?
  CLAP_PARAM_IS_AUTOMATABLE_PER_PORT = 1 shl 9;

  // Does the parameter support the modulation signal?
  CLAP_PARAM_IS_MODULATABLE = 1 shl 10;

  // Does this parameter support per note modulations?
  CLAP_PARAM_IS_MODULATABLE_PER_NOTE_ID = 1 shl 11;

  // Does this parameter support per key modulations?
  CLAP_PARAM_IS_MODULATABLE_PER_KEY = 1 shl 12;

  // Does this parameter support per channel modulations?
  CLAP_PARAM_IS_MODULATABLE_PER_CHANNEL = 1 shl 13;

  // Does this parameter support per port modulations?
  CLAP_PARAM_IS_MODULATABLE_PER_PORT = 1 shl 14;

  // Any change to this parameter will affect the plugin output and requires to be done via
  // process() if the plugin is active.
  //
  // A simple example would be a DC Offset, changing it will change the output signal and must be
  // processed.
  CLAP_PARAM_REQUIRES_PROCESS = 1 shl 15;

  // This parameter represents an enumerated value.
  // If you set this flag, then you must set CLAP_PARAM_IS_STEPPED too.
  // All values from min to max must not have a blank value_to_text().
  CLAP_PARAM_IS_ENUM = 1 shl 16;

type
  Tclap_param_info_flags = uint32_t;

///* This describes a parameter */
  Tclap_param_info = record
    // Stable parameter identifier, it must never change.
    id: Tclap_id;

    flags: Tclap_param_info_flags;

    // This value is optional and set by the plugin.
    // Its purpose is to provide fast access to the plugin parameter object by caching its pointer.
    // For instance:
    //
    // in clap_plugin_params.get_info():
    //    Parameter *p = findParameter(param_id);
    //    param_info->cookie = p;
    //
    // later, in clap_plugin.process():
    //
    //    Parameter *p = (Parameter *)event->cookie;
    //    if (!p) [[unlikely]]
    //       p = findParameter(event->param_id);
    //
    // where findParameter() is a function the plugin implements to map parameter ids to internal
    // objects.
    //
    // Important:
    //  - The cookie is invalidated by a call to clap_host_params->rescan(CLAP_PARAM_RESCAN_ALL) or
    //    when the plugin is destroyed.
    //  - The host will either provide the cookie as issued or nullptr in events addressing
    //    parameters.
    //  - The plugin must gracefully handle the case of a cookie which is nullptr.
    //  - Many plugins will process the parameter events more quickly if the host can provide the
    //    cookie in a faster time than a hashmap lookup per param per event.
    cookie: pointer;

    // The display name. eg: "Volume". This does not need to be unique. Do not include the module
    // text in this. The host should concatenate/format the module + name in the case where showing
    // the name alone would be too vague.
    name: array[0..CLAP_NAME_SIZE - 1] of byte;

    // The module path containing the param, eg: "Oscillators/Wavetable 1".
    // '/' will be used as a separator to show a tree-like structure.
    module: array[0..CLAP_PATH_SIZE - 1] of byte;

    min_value: double;     // Minimum plain value. Must be finite (`std::isfinite` true)
    max_value: double;     // Maximum plain value. Must be finite
    default_value: double; // Default plain value. Must be in [min, max] range.
  end;
  Pclap_param_info = ^Tclap_param_info;

  Tclap_plugin_params = record
    // Returns the number of parameters.
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin);
    count: function(plugin: Pclap_plugin): uint32_t; cdecl;

    // Copies the parameter's info to param_info and returns true on success.
    // Returns true on success.
    // [main-thread]
    //bool (*get_info)(const clap_plugin_t *plugin,
    //                 uint32_t              param_index,
    //                 clap_param_info_t   *param_info);
    get_info: function(plugin: Pclap_plugin; param_index: uint32_t; var param_info: Tclap_param_info): boolean; cdecl;

    // Writes the parameter's current value to out_value. Returns true on success.
    // Returns true on success.
    // [main-thread]
    //bool (*get_value)(const clap_plugin_t *plugin, clap_id param_id, double *value);
    get_value: function(plugin: Pclap_plugin; param_id: Tclap_id; var value: double): boolean; cdecl;

    // Fills out_buffer with a null-terminated UTF-8 string that represents the parameter at the
    // given 'value' argument. eg: "2.3 kHz". The host should always use this to format parameter
    // values before displaying it to the user.
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *value_to_text)(const clap_plugin_t *plugin,
    //                              clap_id              param_id,
    //                              double               value,
    //                              char                *out_buffer,
    //                              uint32_t             out_buffer_capacity);
    value_to_text: function(plugin: Pclap_plugin; param_id: Tclap_id; value: double; out_buffer: PAnsiChar; out_buffer_capacity: uint32_t): boolean; cdecl;

    // Converts the null-terminated UTF-8 param_value_text into a double and writes it to out_value.
    // The host can use this to convert user input into a parameter value.
    // Returns true on success.
    // [main-thread]
    //bool (*text_to_value)(const clap_plugin_t *plugin,
    //                     clap_id              param_id,
    //                     const char          *param_value_text,
    //                     double              *out_value);
    text_to_value: function(plugin: Pclap_plugin; param_id: Tclap_id; param_value_text: PAnsiChar; var out_value: double): boolean; cdecl;

    // Flushes a set of parameter changes.
    // This method must not be called concurrently to clap_plugin->process().
    //
    // Note: if the plugin is processing, then the process() call will already achieve the
    // parameter update (bi-directional), so a call to flush isn't required, also be aware
    // that the plugin may use the sample offset in process(), while this information would be
    // lost within flush().
    //
    // [active ? audio-thread : main-thread]
    //void (*flush)(const clap_plugin_t        *plugin,
    //              const clap_input_events_t  *in,
    //              const clap_output_events_t *out);
    flush: procedure(plugin: Pclap_plugin; inevents: Pclap_input_events; outevents: Pclap_output_events); cdecl;
  end;
  Pclap_plugin_params = ^Tclap_plugin_params;

const
   // The parameter values did change, eg. after loading a preset.
   // The host will scan all the parameters value.
   // The host will not record those changes as automation points.
   // New values takes effect immediately.
   CLAP_PARAM_RESCAN_VALUES = 1 shl 0;

   // The value to text conversion changed, and the text needs to be rendered again.
   CLAP_PARAM_RESCAN_TEXT = 1 shl 1;

   // The parameter info did change, use this flag for:
   // - name change
   // - module change
   // - is_periodic (flag)
   // - is_hidden (flag)
   // New info takes effect immediately.
   CLAP_PARAM_RESCAN_INFO = 1 shl 2;

   // Invalidates everything the host knows about parameters.
   // It can only be used while the plugin is deactivated.
   // If the plugin is activated use clap_host->restart() and delay any change until the host calls
   // clap_plugin->deactivate().
   //
   // You must use this flag if:
   // - some parameters were added or removed.
   // - some parameters had critical changes:
   //   - is_per_note (flag)
   //   - is_per_key (flag)
   //   - is_per_channel (flag)
   //   - is_per_port (flag)
   //   - is_readonly (flag)
   //   - is_bypass (flag)
   //   - is_stepped (flag)
   //   - is_modulatable (flag)
   //   - min_value
   //   - max_value
   //   - cookie
   CLAP_PARAM_RESCAN_ALL = 1 shl 3;

type
  Tclap_param_rescan_flags = uint32_t;

const
   // Clears all possible references to a parameter
   CLAP_PARAM_CLEAR_ALL = 1 shl 0;

   // Clears all automations to a parameter
   CLAP_PARAM_CLEAR_AUTOMATIONS = 1 shl 1;

   // Clears all modulations to a parameter
   CLAP_PARAM_CLEAR_MODULATIONS = 1 shl 2;

type
  Tclap_param_clear_flags = uint32_t;

  Tclap_host_params = record
    // Rescan the full list of parameters according to the flags.
    // [main-thread]
    //void (*rescan)(const clap_host_t *host, clap_param_rescan_flags flags);
    rescan: procedure(host: Pclap_host; flags: Tclap_param_rescan_flags); cdecl;

    // Clears references to a parameter.
    // [main-thread]
    //void (*clear)(const clap_host_t *host, clap_id param_id, clap_param_clear_flags flags);
    clear: procedure(host: Pclap_host; param_id: Tclap_id; flags: Tclap_param_clear_flags); cdecl;

    // Request a parameter flush.
    //
    // The host will then schedule a call to either:
    // - clap_plugin.process()
    // - clap_plugin_params->flush()
    //
    // This function is always safe to use and should not be called from an [audio-thread] as the
    // plugin would already be within process() or flush().
    //
    // [thread-safe,!audio-thread]
    //void (*request_flush)(const clap_host_t *host);
    request_flush: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_params = ^Tclap_host_params;


//ext\note-name.h

const
  CLAP_EXT_NOTE_NAME = AnsiString('clap.note-name');

type
  Tclap_note_name = record
    name: array[0..CLAP_NAME_SIZE - 1] of byte;
    port: int16_t;    // -1 for every port
    key: int16_t;     // -1 for every key
    channel: int16_t; // -1 for every channel
  end;

  Tclap_plugin_note_name = record
    // Return the number of note names
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin);
    count: function(plugin: Pclap_plugin): uint32_t; cdecl;

    // Returns true on success and stores the result into note_name
    // [main-thread]
    //bool (*get)(const clap_plugin_t *plugin, uint32_t index, clap_note_name_t *note_name);
    get: function(plugin: Pclap_plugin; index: uint32_t; var note_name: Tclap_note_name): boolean; cdecl;
  end;
  Pclap_plugin_note_name = ^Tclap_plugin_note_name;

  Tclap_host_note_name = record
    // Informs the host that the note names have changed.
    // [main-thread]
    //void (*changed)(const clap_host_t *host);
    changed: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_note_name = ^Tclap_host_note_name;


//ext\latency.h

const
  CLAP_EXT_LATENCY = AnsiString('clap.latency');

type
  Tclap_plugin_latency = record
    // Returns the plugin latency in samples.
    // [main-thread & (being-activated | active)]
    //uint32_t (*get)(const clap_plugin_t *plugin);
    get: function(plugin: Pclap_plugin): uint32_t; cdecl;
  end;
  Pclap_plugin_latency = ^Tclap_plugin_latency;

  Tclap_host_latency = record
    // Tell the host that the latency changed.
    // The latency is only allowed to change during plugin->activate.
    // If the plugin is activated, call host->request_restart()
    // [main-thread & being-activated]
    //void (*changed)(const clap_host_t *host);
    changed: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_latency = ^Tclap_host_latency;


//ext\tail.h

const
  CLAP_EXT_TAIL = AnsiString('clap.tail');

type
  Tclap_plugin_tail = record
    // Returns tail length in samples.
    // Any value greater or equal to INT32_MAX implies infinite tail.
    // [main-thread,audio-thread]
    //uint32_t (*get)(const clap_plugin_t *plugin);
    get: function(plugin: Pclap_plugin): uint32_t; cdecl;
  end;
  Pclap_plugin_tail = ^Tclap_plugin_tail;

  Tclap_host_tail = record
    // Tell the host that the tail has changed.
    // [audio-thread]
    //void (*changed)(const clap_host_t *host);
    changed: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_tail = ^Tclap_host_tail;


//ext\render.h

const
  CLAP_EXT_RENDER = AnsiString('clap.render');

  // Default setting, for "realtime" processing
  CLAP_RENDER_REALTIME = 0;

  // For processing without realtime pressure
  // The plugin may use more expensive algorithms for higher sound quality.
  CLAP_RENDER_OFFLINE = 1;

type
  Tclap_plugin_render_mode = int32_t;

// The render extension is used to let the plugin know if it has "realtime"
// pressure to process.
//
// If this information does not influence your rendering code, then don't
// implement this extension.
  Tclap_plugin_render = record
    // Returns true if the plugin has a hard requirement to process in real-time.
    // This is especially useful for plugin acting as a proxy to an hardware device.
    // [main-thread]
    //bool (*has_hard_realtime_requirement)(const clap_plugin_t *plugin);
    has_hard_realtime_requirement: function(plugin: Pclap_plugin): boolean; cdecl;

    // Returns true if the rendering mode could be applied.
    // [main-thread]
    //bool (*set)(const clap_plugin_t *plugin, clap_plugin_render_mode mode);
    &set: function(plugin: Pclap_plugin; mode: Tclap_plugin_render_mode): boolean; cdecl;
  end;
  Pclap_plugin_render = ^Tclap_plugin_render;


//ext\thread-check.h

const
  CLAP_EXT_THREAD_CHECK = AnsiString('clap.thread-check');

/// @page thread-check
///
/// CLAP defines two symbolic threads:
///
/// main-thread:
///    This is the thread in which most of the interaction between the plugin and host happens.
///    This will be the same OS thread throughout the lifetime of the plug-in.
///    On macOS and Windows, this must be the thread on which gui and timer events are received
///    (i.e., the main thread of the program).
///    It isn't a realtime thread, yet this thread needs to respond fast enough to allow responsive
///    user interaction, so it is strongly recommended plugins run long,and expensive or blocking
///    tasks such as preset indexing or asset loading in dedicated background threads started by the
///    plugin.
///
/// audio-thread:
///    This thread can be used for realtime audio processing. Its execution should be as
///    deterministic as possible to meet the audio interface's deadline (can be <1ms). There are a
///    known set of operations that should be avoided: malloc() and free(), contended locks and
///    mutexes, I/O, waiting, and so forth.
///
///    The audio-thread is symbolic, there isn't one OS thread that remains the
///    audio-thread for the plugin lifetime. A host is may opt to have a
///    thread pool and the plugin.process() call may be scheduled on different OS threads over time.
///    However, the host must guarantee that single plugin instance will not be two audio-threads
///    at the same time.
///
///    Functions marked with [audio-thread] **ARE NOT CONCURRENT**. The host may mark any OS thread,
///    including the main-thread as the audio-thread, as long as it can guarantee that only one OS
///    thread is the audio-thread at a time in a plugin instance. The audio-thread can be seen as a
///    concurrency guard for all functions marked with [audio-thread].
///
///    The real-time constraint on the [audio-thread] interacts closely with the render extension.
///    If a plugin doesn't implement render, then that plugin must have all [audio-thread] functions
///    meet the real time standard. If the plugin does implement render, and returns true when
///    render mode is set to real-time or if the plugin advertises a hard realtime requirement, it
///    must implement realtime constraints. Hosts also provide functions marked [audio-thread].
///    These can be safely called by a plugin in the audio thread. Therefore hosts must either (1)
///    implement those functions meeting the real-time constraints or (2) not process plugins which
///    advertise a hard realtime constraint or don't implement the render extension. Hosts which
///    provide [audio-thread] functions outside these conditions may experience inconsistent or
///    inaccurate rendering.
///
///  Clap also tags some functions as [thread-safe]. Functions tagged as [thread-safe] can be called
///  from any thread unless explicitly counter-indicated (for instance [thread-safe, !audio-thread])
///  and may be called concurrently. Since a [thread-safe] function may be called from the
///  [audio-thread] unless explicitly counter-indicated, it must also meet the realtime constraints
///  as describes above.

// This interface is useful to do runtime checks and make
// sure that the functions are called on the correct threads.
// It is highly recommended that hosts implement this extension.
type
  Tclap_host_thread_check = record
    // Returns true if "this" thread is the main thread.
    // [thread-safe]
    //bool (*is_main_thread)(const clap_host_t *host);
    is_main_thread: function(host: Pclap_host): boolean; cdecl;

    // Returns true if "this" thread is one of the audio threads.
    // [thread-safe]
    //bool (*is_audio_thread)(const clap_host_t *host);
    is_audio_thread: function(host: Pclap_host): boolean; cdecl;
  end;
  Pclap_host_thread_check = ^Tclap_host_thread_check;


//ext\context-menu.h

// This extension lets the host and plugin exchange menu items and let the plugin ask the host to
// show its context menu.

const
   CLAP_EXT_CONTEXT_MENU = AnsiString('clap.context-menu/1');

// The latest draft is 100% compatible.
// This compat ID may be removed in 2026.
   CLAP_EXT_CONTEXT_MENU_COMPAT = AnsiString('clap.context-menu.draft/0');

// There can be different target kind for a context menu
   CLAP_CONTEXT_MENU_TARGET_KIND_GLOBAL = 0;
   CLAP_CONTEXT_MENU_TARGET_KIND_PARAM = 1;

// Describes the context menu target
type
  Tclap_context_menu_target = record
    kind: uint32_t;
    id: Tclap_id;
  end;
  Pclap_context_menu_target = ^Tclap_context_menu_target;

const
   // Adds a clickable menu entry.
   // data: const clap_context_menu_item_entry_t*
   CLAP_CONTEXT_MENU_ITEM_ENTRY = 0;

   // Adds a clickable menu entry which will feature both a checkmark and a label.
   // data: const clap_context_menu_item_check_entry_t*
   CLAP_CONTEXT_MENU_ITEM_CHECK_ENTRY = 1;

   // Adds a separator line.
   // data: NULL
   CLAP_CONTEXT_MENU_ITEM_SEPARATOR = 2;

   // Starts a sub menu with the given label.
   // data: const clap_context_menu_item_begin_submenu_t*
   CLAP_CONTEXT_MENU_ITEM_BEGIN_SUBMENU = 3;

   // Ends the current sub menu.
   // data: NULL
   CLAP_CONTEXT_MENU_ITEM_END_SUBMENU = 4;

   // Adds a title entry
   // data: const clap_context_menu_item_title_t *
   CLAP_CONTEXT_MENU_ITEM_TITLE = 5;
   
type
  Tclap_context_menu_item_kind = uint32_t;

  Tclap_context_menu_entry = record
    // text to be displayed
    &label: PAnsiChar;

    // if false, then the menu entry is greyed out and not clickable
    is_enabled: boolean;
    action_id: Tclap_id;
  end;
  Pclap_context_menu_entry = ^Tclap_context_menu_entry;

  Tclap_context_menu_check_entry = record
    // text to be displayed
    &label: PAnsiChar;

    // if false, then the menu entry is greyed out and not clickable
    is_enabled: boolean;

    // if true, then the menu entry will be displayed as checked
    is_checked: boolean;
    action_id: Tclap_id;
  end;
  Pclap_context_menu_check_entry = ^Tclap_context_menu_check_entry;

  Tclap_context_menu_item_title = record
    // text to be displayed
    title: PAnsiChar;

    // if false, then the menu entry is greyed out
    is_enabled: boolean;
  end;
  Pclap_context_menu_item_title = ^Tclap_context_menu_item_title;

  Tclap_context_menu_submenu = record
    // text to be displayed
    &label: PAnsiChar;

    // if false, then the menu entry is greyed out and won't show submenu
    is_enabled: boolean;
  end;
  Pclap_context_menu_submenu = ^Tclap_context_menu_submenu;

// Context menu builder.
// This object isn't thread-safe and must be used on the same thread as it was provided.
  Pclap_context_menu_builder = ^Tclap_context_menu_builder;
  Tclap_context_menu_builder = record
    ctx: TObject;

    // Adds an entry to the menu.
    // item_data type is determined by item_kind.
    // Returns true on success.
    //bool(CLAP_ABI *add_item)(const struct clap_context_menu_builder *builder,
    //                         clap_context_menu_item_kind_t           item_kind,
    //                         const void                             *item_data);
    add_item: function(builder: Pclap_context_menu_builder; item_kind: Tclap_context_menu_item_kind; item_data: pointer): boolean; cdecl;

    // Returns true if the menu builder supports the given item kind
    //bool(CLAP_ABI *supports)(const struct clap_context_menu_builder *builder,
    //                         clap_context_menu_item_kind_t           item_kind);
    supports: function(builder: Pclap_context_menu_builder; item_kind: Tclap_context_menu_item_kind): boolean; cdecl;
  end;

  Tclap_plugin_context_menu = record
    // Insert plugin's menu items into the menu builder.
    // If target is null, assume global context
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *populate)(const clap_plugin_t               *plugin,
    //                         const clap_context_menu_target_t  *target,
    //                         const clap_context_menu_builder_t *builder);
    populate: function(plugin: Pclap_plugin; target: Pclap_context_menu_target; builder: Pclap_context_menu_builder): boolean; cdecl;

    // Performs the given action, which was previously provided to the host via populate().
    // If target is null, assume global context
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *perform)(const clap_plugin_t              *plugin,
    //                        const clap_context_menu_target_t *target,
    //                        clap_id                           action_id);
    perform: function(plugin: Pclap_plugin; target: Pclap_context_menu_target; action_id: Tclap_id): boolean; cdecl;
  end;
  Pclap_plugin_context_menu = ^Tclap_plugin_context_menu;

  Tclap_host_context_menu = record
    // Insert host's menu items into the menu builder.
    // If target is null, assume global context
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *populate)(const clap_host_t                 *host,
    //                         const clap_context_menu_target_t  *target,
    //                         const clap_context_menu_builder_t *builder);
    populate: function(host: Pclap_host; target: Pclap_context_menu_target; builder: Pclap_context_menu_builder): boolean; cdecl;

    // Performs the given action, which was previously provided to the plugin via populate().
    // If target is null, assume global context
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *perform)(const clap_host_t                *host,
    //                        const clap_context_menu_target_t *target,
    //                        clap_id action_id);
    perform: function(host: Pclap_host; target: Pclap_context_menu_target; action_id: Tclap_id): boolean; cdecl;

    // Returns true if the host can display a popup menu for the plugin.
    // This may depend upon the current windowing system used to display the plugin, so the
    // return value is invalidated after creating the plugin window.
    // [main-thread]
    //bool(CLAP_ABI *can_popup)(const clap_host_t *host);
    can_popup: function(host: Pclap_host): boolean; cdecl;

    // Shows the host popup menu for a given parameter.
    // If the plugin is using embedded GUI, then x and y are relative to the plugin's window,
    // otherwise they're absolute coordinate, and screen index might be set accordingly.
    // If target is null, assume global context
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *popup)(const clap_host_t                *host,
    //                      const clap_context_menu_target_t *target,
    //                      int32_t                           screen_index,
    //                      int32_t                           x,
    //                      int32_t                           y);
    popup: function(host: Pclap_host; target: Pclap_context_menu_target; screen_index, x, y: int32): boolean; cdecl;
  end;
  Pclap_host_context_menu = ^Tclap_host_context_menu;


//ext\param-indication.h

// This extension lets the host tell the plugin to display a little color based indication on the
// parameter. This can be used to indicate:
// - a physical controller is mapped to a parameter
// - the parameter is current playing an automation
// - the parameter is overriding the automation
// - etc...
//
// The color semantic depends upon the host here and the goal is to have a consistent experience
// across all plugins.

const
  CLAP_EXT_PARAM_INDICATION = AnsiString('clap.param-indication/4');

// The latest draft is 100% compatible.
// This compat ID may be removed in 2026.
  CLAP_EXT_PARAM_INDICATION_COMPAT = AnsiString('clap.param-indication.draft/4');

  // The host doesn't have an automation for this parameter
  CLAP_PARAM_INDICATION_AUTOMATION_NONE = 0;

  // The host has an automation for this parameter, but it isn't playing it
  CLAP_PARAM_INDICATION_AUTOMATION_PRESENT = 1;

  // The host is playing an automation for this parameter
  CLAP_PARAM_INDICATION_AUTOMATION_PLAYING = 2;

  // The host is recording an automation on this parameter
  CLAP_PARAM_INDICATION_AUTOMATION_RECORDING = 3;

  // The host should play an automation for this parameter, but the user has started to adjust this
  // parameter and is overriding the automation playback
  CLAP_PARAM_INDICATION_AUTOMATION_OVERRIDING = 4;

type
  Tclap_plugin_param_indication = record
    // Sets or clears a mapping indication.
    //
    // has_mapping: does the parameter currently has a mapping?
    // color: if set, the color to use to highlight the control in the plugin GUI
    // label: if set, a small string to display on top of the knob which identifies the hardware
    // controller description: if set, a string which can be used in a tooltip, which describes the
    // current mapping
    //
    // Parameter indications should not be saved in the plugin context, and are off by default.
    // [main-thread]
    //void(CLAP_ABI *set_mapping)(const clap_plugin_t *plugin,
    //                            clap_id              param_id,
    //                            bool                 has_mapping,
    //                            const clap_color_t  *color,
    //                            const char          *label,
    //                            const char          *description);
    set_mapping: procedure(plugin: Pclap_plugin; param_id: Tclap_id; has_mapping: boolean; color: Pclap_color; &label, description: PAnsiChar); cdecl;

    // Sets or clears an automation indication.
    //
    // automation_state: current automation state for the given parameter
    // color: if set, the color to use to display the automation indication in the plugin GUI
    //
    // Parameter indications should not be saved in the plugin context, and are off by default.
    // [main-thread]
    //void(CLAP_ABI *set_automation)(const clap_plugin_t *plugin,
    //                               clap_id              param_id,
    //                               uint32_t             automation_state,
    //                               const clap_color_t  *color);
    set_automation: procedure(plugin: Pclap_plugin; param_id: Tclap_id; automation_state: uint32_t; color: Pclap_color); cdecl;
  end;
  Pclap_plugin_param_indication = ^Tclap_plugin_param_indication;


//ext\remote-controls.h

// This extension let the plugin provide a structured way of mapping parameters to an hardware
// controller.
//
// This is done by providing a set of remote control pages organized by section.
// A page contains up to 8 controls, which references parameters using param_id.
//
// |`- [section:main]
// |    `- [name:main] performance controls
// |`- [section:osc]
// |   |`- [name:osc1] osc1 page
// |   |`- [name:osc2] osc2 page
// |   |`- [name:osc-sync] osc sync page
// |    `- [name:osc-noise] osc noise page
// |`- [section:filter]
// |   |`- [name:flt1] filter 1 page
// |    `- [name:flt2] filter 2 page
// |`- [section:env]
// |   |`- [name:env1] env1 page
// |    `- [name:env2] env2 page
// |`- [section:lfo]
// |   |`- [name:lfo1] env1 page
// |    `- [name:lfo2] env2 page
//  `- etc...
//
// One possible workflow is to have a set of buttons, which correspond to a section.
// Pressing that button once gets you to the first page of the section.
// Press it again to cycle through the section's pages.
const
  CLAP_EXT_REMOTE_CONTROLS = AnsiString('clap.remote-controls/2');

  CLAP_EXT_REMOTE_CONTROLS_COMPAT = AnsiString('clap.remote-controls.draft/2');

  CLAP_REMOTE_CONTROLS_COUNT = 8;

type
  Tclap_remote_controls_page = record
    section_name: array[0..CLAP_NAME_SIZE - 1] of byte;
    page_id: Tclap_id;
    page_name: array[0..CLAP_NAME_SIZE - 1] of byte;
    param_ids: array[0..CLAP_REMOTE_CONTROLS_COUNT - 1] of Tclap_id;

    // This is used to separate device pages versus preset pages.
    // If true, then this page is specific to this preset.
    is_for_preset: boolean;
  end;
  Pclap_remote_controls_page = ^Tclap_remote_controls_page;

  Tclap_plugin_remote_controls = record
    // Returns the number of pages.
    // [main-thread]
    //uint32_t(CLAP_ABI *count)(const clap_plugin_t *plugin);
    count: function(plugin: Pclap_plugin): uint32_t; cdecl;

    // Get a page by index.
    // Returns true on success and stores the result into page.
    // [main-thread]
    //bool(CLAP_ABI *get)(const clap_plugin_t         *plugin,
    //                    uint32_t                     page_index,
    //                    clap_remote_controls_page_t *page);
    get: function(plugin: Pclap_plugin; page_index: uint32_t; page: Pclap_remote_controls_page): boolean; cdecl;
  end;
  Pclap_plugin_remote_controls = ^Tclap_plugin_remote_controls;

  Tclap_host_remote_controls = record
    // Informs the host that the remote controls have changed.
    // [main-thread]
    //void(CLAP_ABI *changed)(const clap_host_t *host);
    changed: procedure(host: Pclap_host); cdecl;

    // Suggest a page to the host because it corresponds to what the user is currently editing in the
    // plugin's GUI.
    // [main-thread]
    //void(CLAP_ABI *suggest_page)(const clap_host_t *host, clap_id page_id);
    suggest_page: procedure(host: Pclap_host; page_id: Tclap_id); cdecl;
  end;
  Pclap_host_remote_controls = ^Tclap_host_remote_controls;


//ext\track-info.h

// This extension let the plugin query info about the track it's in.
// It is useful when the plugin is created, to initialize some parameters (mix, dry, wet)
// and pick a suitable configuration regarding audio port type and channel count.
const
  CLAP_EXT_TRACK_INFO = AnsiString('clap.track-info/1');

// The latest draft is 100% compatible.
// This compat ID may be removed in 2026.
  CLAP_EXT_TRACK_INFO_COMPAT = AnsiString('clap.track-info.draft/1');

  CLAP_TRACK_INFO_HAS_TRACK_NAME = 1 shl 0;
  CLAP_TRACK_INFO_HAS_TRACK_COLOR = 1 shl 1;
  CLAP_TRACK_INFO_HAS_AUDIO_CHANNEL = 1 shl 2;
  // This plugin is on a return track, initialize with wet 100%
  CLAP_TRACK_INFO_IS_FOR_RETURN_TRACK = 1 shl 3;
  // This plugin is on a bus track, initialize with appropriate settings for bus processing
  CLAP_TRACK_INFO_IS_FOR_BUS = 1 shl 4;
  // This plugin is on the master, initialize with appropriate settings for channel processing
  CLAP_TRACK_INFO_IS_FOR_MASTER = 1 shl 5;

type
  Tclap_track_info = record
    flags: uint64_t; // see the flags above
    // track name, available if flags contain CLAP_TRACK_INFO_HAS_TRACK_NAME
    name: array[0..CLAP_NAME_SIZE - 1] of byte;
    // track color, available if flags contain CLAP_TRACK_INFO_HAS_TRACK_COLOR
    color: Tclap_color;
    // available if flags contain CLAP_TRACK_INFO_HAS_AUDIO_CHANNEL
    // see audio-ports.h, struct clap_audio_port_info to learn how to use channel count and port type
    audio_channel_count: int32_t;
    audio_port_type: PAnsiChar;
  end;
  Pclap_track_info = ^Tclap_track_info;
  Tclap_plugin_track_info = record
    // Called when the info changes.
    // [main-thread]
    //void(CLAP_ABI *changed)(const clap_plugin_t *plugin);
    changed: procedure(plugin: Pclap_plugin); cdecl;
  end;
  Pclap_plugin_track_info = ^Tclap_plugin_track_info;
  Tclap_host_track_info = record
    // Get info about the track the plugin belongs to.
    // Returns true on success and stores the result into info.
    // [main-thread]
    //bool(CLAP_ABI *get)(const clap_host_t *host, clap_track_info_t *info);
    get: function(host: Pclap_host; info: Pclap_track_info): boolean; cdecl;
  end;
  Pclap_host_track_info = ^Tclap_host_track_info;


//ext\draft\transport-control.h

// This extension lets the plugin submit transport requests to the host.
// The host has no obligation to execute these requests, so the interface may be
// partially working.

const
  CLAP_EXT_TRANSPORT_CONTROL = AnsiString('clap.transport-control/1');

type
  Tclap_host_transport_control = record
    // Jumps back to the start point and starts the transport
    // [main-thread]
    //void(CLAP_ABI *request_start)(const clap_host_t *host);
    request_start: procedure(host: Pclap_host); cdecl;

    // Stops the transport, and jumps to the start point
    // [main-thread]
    //void(CLAP_ABI *request_stop)(const clap_host_t *host);
    request_stop: procedure(host: Pclap_host); cdecl;

    // If not playing, starts the transport from its current position
    // [main-thread]
    //void(CLAP_ABI *request_continue)(const clap_host_t *host);
    request_continue: procedure(host: Pclap_host); cdecl;

    // If playing, stops the transport at the current position
    // [main-thread]
    //void(CLAP_ABI *request_pause)(const clap_host_t *host);
    request_pause: procedure(host: Pclap_host); cdecl;

    // Equivalent to what "space bar" does with most DAWs
    // [main-thread]
    //void(CLAP_ABI *request_toggle_play)(const clap_host_t *host);
    request_toggle_play: procedure(host: Pclap_host); cdecl;

    // Jumps the transport to the given position.
    // Does not start the transport.
    // [main-thread]
    //void(CLAP_ABI *request_jump)(const clap_host_t *host, clap_beattime position);
    request_jump: procedure(host: Pclap_host; position: Tclap_beattime); cdecl;

    // Sets the loop region
    // [main-thread]
    //void(CLAP_ABI *request_loop_region)(const clap_host_t *host,
    //                                   clap_beattime      start,
    //                                   clap_beattime      duration);
    request_loop_region: procedure(host: Pclap_host; start, duration: Tclap_beattime); cdecl;

    // Toggles looping
    // [main-thread]
    //void(CLAP_ABI *request_toggle_loop)(const clap_host_t *host);
    request_toggle_loop: procedure(host: Pclap_host); cdecl;

    // Enables/Disables looping
    // [main-thread]
    //void(CLAP_ABI *request_enable_loop)(const clap_host_t *host, bool is_enabled);
    request_enable_loop: procedure(host: Pclap_host; is_enabled: boolean); cdecl;

    // Enables/Disables recording
    // [main-thread]
    //void(CLAP_ABI *request_record)(const clap_host_t *host, bool is_recording);
    request_record: procedure(host: Pclap_host; is_recording: boolean); cdecl;

    // Toggles recording
    // [main-thread]
    //void(CLAP_ABI *request_toggle_record)(const clap_host_t *host);
    request_toggle_record: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_transport_control = ^Tclap_host_transport_control;


//ext\draft\gain-adjustment-metering.h

// This extension lets the plugin report the current gain adjustment
// (typically, gain reduction) to the host.

const
  CLAP_EXT_GAIN_ADJUSTMENT_METERING = 'clap.gain-adjustment-metering/0';

type
  Tclap_plugin_gain_adjustment_metering = record
    // Returns the current gain adjustment in dB. The value is intended
    // for informational display, for example in a host meter or tooltip.
    // The returned value represents the gain adjustment that the plugin
    // applied to the last sample in the most recently processed block.
    //
    // The returned value is in dB. Zero means the plugin is applying no gain
    // reduction, or is not processing. A negative value means the plugin is
    // applying gain reduction, as with a compressor or limiter. A positive
    // value means the plugin is adding gain, as with an expander. The value
    // represents the dynamic gain reduction or expansion applied by the
    // plugin, before any make-up gain or other adjustment. A single value is
    // returned for all audio channels.
    //
    // [audio-thread]
    //double(CLAP_ABI *get)(const clap_plugin_t *plugin);
    get: function(plugin: Pclap_plugin): double; cdecl;
  end;
  Pclap_plugin_gain_adjustment_metering = ^Tclap_plugin_gain_adjustment_metering;


//ext\preset-load.h

const
  CLAP_EXT_PRESET_LOAD = AnsiString('clap.preset-load/2');

// The latest draft is 100% compatible.
// This compat ID may be removed in 2026.
  CLAP_EXT_PRESET_LOAD_COMPAT = AnsiString('clap.preset-load.draft/2');

type
  Tclap_plugin_preset_load = record
    // Loads a preset in the plugin native preset file format from a location.
    // The preset discovery provider defines the location and load_key to be passed to this function.
    // Returns true on success.
    // [main-thread]
    //bool(CLAP_ABI *from_location)(const clap_plugin_t *plugin,
    //                              uint32_t             location_kind,
    //                              const char          *location,
    //                              const char          *load_key);
    from_location: function(plugin: Pclap_plugin; location_kind: uint32_t; location, load_key: PAnsiChar): boolean; cdecl;
  end;
  Pclap_plugin_preset_load = ^Tclap_plugin_preset_load;

  Tclap_host_preset_load = record
    // Called if clap_plugin_preset_load.load() failed.
    // os_error: the operating system error, if applicable. If not applicable set it to a non-error
    // value, eg: 0 on unix and Windows.
    //
    // [main-thread]
    //void(CLAP_ABI *on_error)(const clap_host_t *host,
    //                         uint32_t           location_kind,
    //                         const char        *location,
    //                         const char        *load_key,
    //                         int32_t            os_error,
    //                         const char        *msg);
    on_error: procedure(host: Pclap_host; location_kind: uint32_t; location, load_key: PAnsiChar; os_error: int32_t; msg: PAnsiChar); cdecl;

    // Informs the host that the following preset has been loaded.
    // This contributes to keep in sync the host preset browser and plugin preset browser.
    // If the preset was loaded from a container file, then the load_key must be set, otherwise it
    // must be null.
    //
    // [main-thread]
    //void(CLAP_ABI *loaded)(const clap_host_t *host,
    //                       uint32_t           location_kind,
    //                       const char        *location,
    //                       const char        *load_key);
    loaded: procedure(host: Pclap_host; location_kind: uint32_t; location, load_key: PAnsiChar); cdecl;
  end;
  Pclap_host_preset_load = ^Tclap_host_preset_load;


//factory\preset-discovery.h

{
   Preset Discovery API.

   Preset Discovery enables a plug-in host to identify where presets are found, what
   extensions they have, which plug-ins they apply to, and other metadata associated with the
   presets so that they can be indexed and searched for quickly within the plug-in host's browser.

   This has a number of advantages for the user:
   - it allows them to browse for presets from one central location in a consistent way
   - the user can browse for presets without having to commit to a particular plug-in first

   The API works as follow to index presets and presets metadata:
   1. clap_plugin_entry.get_factory(CLAP_PRESET_DISCOVERY_FACTORY_ID)
   2. clap_preset_discovery_factory_t.create(...)
   3. clap_preset_discovery_provider.init() (only necessary the first time, declarations
   can be cached)
        `-> clap_preset_discovery_indexer.declare_filetype()
        `-> clap_preset_discovery_indexer.declare_location()
        `-> clap_preset_discovery_indexer.declare_soundpack() (optional)
        `-> clap_preset_discovery_indexer.set_invalidation_watch_file() (optional)
   4. crawl the given locations and monitor file system changes
        `-> clap_preset_discovery_indexer.get_metadata() for each presets files

   Then to load a preset, use ext/draft/preset-load.h.
   TODO: create a dedicated repo for other plugin abi preset-load extension.

   The design of this API deliberately does not define a fixed set tags or categories. It is the
   plug-in host's job to try to intelligently map the raw list of features that are found for a
   preset and to process this list to generate something that makes sense for the host's tagging and
   categorization system. The reason for this is to reduce the work for a plug-in developer to add
   Preset Discovery support for their existing preset file format and not have to be concerned with
   all the different hosts and how they want to receive the metadata.

   VERY IMPORTANT:
   - the whole indexing process has to be **fast**
      - clap_preset_provider->get_metadata() has to be fast and avoid unnecessary operations
   - the whole indexing process must not be interactive
      - don't show dialogs, windows, ...
      - don't ask for user input
}

// Use it to retrieve const clap_preset_discovery_factory_t* from
// clap_plugin_entry.get_factory()
const
  CLAP_PRESET_DISCOVERY_FACTORY_ID = AnsiString('clap.preset-discovery-factory/2');

// The latest draft is 100% compatible.
// This compat ID may be removed in 2026.
  CLAP_PRESET_DISCOVERY_FACTORY_ID_COMPAT = AnsiString('clap.preset-discovery-factory/draft-2');

  // The preset are located in a file on the OS filesystem.
  // The location is then a path which works with the OS file system functions (open, stat, ...)
  // So both '/' and '\' shall work on Windows as a separator.
  CLAP_PRESET_DISCOVERY_LOCATION_FILE = 0;

  // The preset is bundled within the plugin DSO itself.
  // The location must then be null, as the preset are within the plugin itself and then the plugin
  // will act as a preset container.
  CLAP_PRESET_DISCOVERY_LOCATION_PLUGIN = 1;


  // This is for factory or sound-pack presets.
  CLAP_PRESET_DISCOVERY_IS_FACTORY_CONTENT = 1 shl 0;

  // This is for user presets.
  CLAP_PRESET_DISCOVERY_IS_USER_CONTENT = 1 shl 1;

  // This location is meant for demo presets, those are preset which may trigger
  // some limitation in the plugin because they require additional features which the user
  // needs to purchase or the content itself needs to be bought and is only available in
  // demo mode.
  CLAP_PRESET_DISCOVERY_IS_DEMO_CONTENT = 1 shl 2;

  // This preset is a user's favorite
  CLAP_PRESET_DISCOVERY_IS_FAVORITE = 1 shl 3;

// Receiver that receives the metadata for a single preset file.
// The host would define the various callbacks in this interface and the preset parser function
// would then call them.
//
// This interface isn't thread-safe.
type
  Pclap_preset_discovery_metadata_receiver = ^Tclap_preset_discovery_metadata_receiver;
  Tclap_preset_discovery_metadata_receiver = record
    receiver_data: TObject; // reserved pointer for the metadata receiver

    // If there is an error reading metadata from a file this should be called with an error
    // message.
    // os_error: the operating system error, if applicable. If not applicable set it to a non-error
    // value, eg: 0 on unix and Windows.
    //void(CLAP_ABI *on_error)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                         int32_t                                               os_error,
    //                         const char                                           *error_message);
    on_error: procedure(receiver: Pclap_preset_discovery_metadata_receiver; os_error: int32_t; error_message: PAnsiChar); cdecl;

    // This must be called for every preset in the file and before any preset metadata is
    // sent with the calls below.
    //
    // If the preset file is a preset container then name and load_key are mandatory, otherwise
    // they are optional.
    //
    // The load_key is a machine friendly string used to load the preset inside the container via a
    // the preset-load plug-in extension. The load_key can also just be the subpath if that's what the
    // plugin wants but it could also be some other unique id like a database primary key or a
    // binary offset. It's use is entirely up to the plug-in.
    //
    // If the function returns false, then the provider must stop calling back into the receiver.
    //bool(CLAP_ABI *begin_preset)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                             const char                                           *name,
    //                             const char                                           *load_key);
    begin_preset: function(receiver: Pclap_preset_discovery_metadata_receiver; name, load_key: PAnsiChar): boolean; cdecl;

    // Adds a plug-in id that this preset can be used with.
    //void(CLAP_ABI *add_plugin_id)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                              const clap_universal_plugin_id_t                               *plugin_id);
    add_plugin_id: procedure(receiver: Pclap_preset_discovery_metadata_receiver; plugin_id: Pclap_universal_plugin_id); cdecl;

    // Sets the sound pack to which the preset belongs to.
    //void(CLAP_ABI *set_soundpack_id)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                                  const char *soundpack_id);
    set_soundpack_id: procedure(receiver: Pclap_preset_discovery_metadata_receiver; soundpack_id: PAnsiChar); cdecl;

    // Sets the flags, see clap_preset_discovery_flags.
    // If unset, they are then inherited from the location.
    //void(CLAP_ABI *set_flags)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                          uint32_t                                              flags);
    set_flags: procedure(receiver: Pclap_preset_discovery_metadata_receiver; flags: uint32_t); cdecl;

    // Adds a creator name for the preset.
    //void(CLAP_ABI *add_creator)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                            const char                                           *creator);
    add_creator: procedure(receiver: Pclap_preset_discovery_metadata_receiver; creator: PAnsiChar); cdecl;

    // Sets a description of the preset.
    //void(CLAP_ABI *set_description)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                                const char *description);
    set_description: procedure(receiver: Pclap_preset_discovery_metadata_receiver; description: PAnsiChar); cdecl;

    // Sets the creation time and last modification time of the preset.
    // The timestamps are in seconds since UNIX EPOCH, see C's time_t time(time_t *).
    // If one of the time isn't known, then set it to CLAP_TIMESTAMP_UNKNOWN.
    // If this function is not called, then the indexer may look at the file's creation and
    // modification time.
    //void(CLAP_ABI *set_timestamps)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                               clap_timestamp creation_time,
    //                               clap_timestamp modification_time);
    set_timestamps: procedure(receiver: Pclap_preset_discovery_metadata_receiver; creation_time, modification_time: Tclap_timestamp); cdecl;

    // Adds a feature to the preset.
    //
    // The feature string is arbitrary, it is the indexer's job to understand it and remap it to its
    // internal categorization and tagging system.
    //
    // However, the strings from plugin-features.h should be understood by the indexer and one of the
    // plugin category could be provided to determine if the preset will result into an audio-effect,
    // instrument, ...
    //
    // Examples:
    // kick, drum, tom, snare, clap, cymbal, bass, lead, metalic, hardsync, crossmod, acid,
    // distorted, drone, pad, dirty, etc...
    //void(CLAP_ABI *add_feature)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                            const char                                           *feature);
    add_feature: procedure(receiver: Pclap_preset_discovery_metadata_receiver; feature: PAnsiChar); cdecl;

    // Adds extra information to the metadata.
    //void(CLAP_ABI *add_extra_info)(const struct clap_preset_discovery_metadata_receiver *receiver,
    //                               const char                                           *key,
    //                               const char                                           *value);
    add_extra_info: procedure(receiver: Pclap_preset_discovery_metadata_receiver; key, value: PAnsiChar); cdecl;
  end;

  Tclap_preset_discovery_filetype = record
    name: PAnsiChar;
    description: PAnsiChar; // optional

    // `.' isn't included in the string.
    // If empty or NULL then every file should be matched.
    file_extension: PAnsiChar;
  end;
  Pclap_preset_discovery_filetype = ^Tclap_preset_discovery_filetype;

// Defines a place in which to search for presets
  Tclap_preset_discovery_location = record
    flags: uint32_t;     // see enum clap_preset_discovery_flags
    name: PAnsiChar;     // name of this location
    kind: uint32_t;      // See clap_preset_discovery_location_kind

    // Actual location in which to crawl presets.
    // For FILE kind, the location can be either a path to a directory or a file.
    // For PLUGIN kind, the location must be null.
   	location: PAnsiChar;
  end;
  Pclap_preset_discovery_location = ^Tclap_preset_discovery_location;

// Describes an installed sound pack.
  Tclap_preset_discovery_soundpack = record
    flags: uint32_t;         // see enum clap_preset_discovery_flags
    id: PAnsiChar;           // sound pack identifier
    name: PAnsiChar;         // name of this sound pack
    description: PAnsiChar;  // optional, reasonably short description of the sound pack
    homepage_url: PAnsiChar; // optional, url to the pack's homepage
    vendor: PAnsiChar;       // optional, sound pack's vendor
    image_path: PAnsiChar;   // optional, an image on disk
    release_timestamp: Tclap_timestamp; // release date, CLAP_TIMESTAMP_UNKNOWN if unavailable
  end;
  Pclap_preset_discovery_soundpack = ^Tclap_preset_discovery_soundpack;

// Describes a preset provider
  Tclap_preset_discovery_provider_descriptor = record
    clap_version: Tclap_version; // initialized to CLAP_VERSION
    id: PAnsiChar;           // see plugin.h for advice on how to choose a good identifier
    name: PAnsiChar;         // eg: "Diva's preset provider"
    vendor: PAnsiChar;       // optional, eg: u-he
  end;
  Pclap_preset_discovery_provider_descriptor = ^Tclap_preset_discovery_provider_descriptor;

// This interface isn't thread-safe.
  Pclap_preset_discovery_provider = ^Tclap_preset_discovery_provider;
  Tclap_preset_discovery_provider = record
    desc: Pclap_preset_discovery_provider_descriptor;

    provider_data: TObject; // reserved pointer for the provider

    // Initialize the preset provider.
    // It should declare all its locations, filetypes and sound packs.
    // Returns false if initialization failed.
    //bool(CLAP_ABI *init)(const struct clap_preset_discovery_provider *provider);
    init: function(provider: Pclap_preset_discovery_provider): boolean; cdecl;

    // Destroys the preset provider
    //void(CLAP_ABI *destroy)(const struct clap_preset_discovery_provider *provider);
    destroy: procedure(provider: Pclap_preset_discovery_provider); cdecl;

    // reads metadata from the given file and passes them to the metadata receiver
    // Returns true on success.
    //bool(CLAP_ABI *get_metadata)(const struct clap_preset_discovery_provider     *provider,
    //                             uint32_t                                         location_kind,
    //                             const char                                      *location,
    //                             const clap_preset_discovery_metadata_receiver_t *metadata_receiver);
    get_metadata: procedure(provider: Pclap_preset_discovery_provider; location_kind: uint32_t; location: PAnsiChar; metadata_receiver: Pclap_preset_discovery_metadata_receiver); cdecl;

    // Query an extension.
    // The returned pointer is owned by the provider.
    // It is forbidden to call it before provider->init().
    // You can call it within provider->init() call, and after.
    //const void *(CLAP_ABI *get_extension)(const struct clap_preset_discovery_provider *provider,
    //                                      const char                                  *extension_id);
    get_extension: function(provider: Pclap_preset_discovery_provider; extension_id: PAnsiChar): pointer; cdecl;
  end;

// This interface isn't thread-safe
  Pclap_preset_discovery_indexer = ^Tclap_preset_discovery_indexer;
  Tclap_preset_discovery_indexer = record
    clap_version: Tclap_version; // initialized to CLAP_VERSION
    name: PAnsiChar;         // eg: "Bitwig Studio"
    vendor: PAnsiChar;       // optional, eg: "Bitwig GmbH"
    url: PAnsiChar;          // optional, eg: "https://bitwig.com"
    version: PAnsiChar;      // optional, eg: "4.3", see plugin.h for advice on how to format the version

    indexer_data: TObject; // reserved pointer for the indexer

    // Declares a preset filetype.
    // Don't callback into the provider during this call.
    // Returns false if the filetype is invalid.
    //bool(CLAP_ABI *declare_filetype)(const struct clap_preset_discovery_indexer *indexer,
    //                                 const clap_preset_discovery_filetype_t     *filetype);
    declare_filetype: function(indexer: Pclap_preset_discovery_indexer; filetype: Pclap_preset_discovery_filetype): boolean; cdecl;

    // Declares a preset location.
    // Don't callback into the provider during this call.
    // Returns false if the location is invalid.
    //bool(CLAP_ABI *declare_location)(const struct clap_preset_discovery_indexer *indexer,
    //                                 const clap_preset_discovery_location_t     *location);
    declare_location: function(indexer: Pclap_preset_discovery_indexer; location: Pclap_preset_discovery_location): boolean; cdecl;

    // Declares a sound pack.
    // Don't callback into the provider during this call.
    // Returns false if the sound pack is invalid.
    //bool(CLAP_ABI *declare_soundpack)(const struct clap_preset_discovery_indexer *indexer,
    //                                  const clap_preset_discovery_collection_t   *soundpack);
    declare_soundpack: function(indexer: Pclap_preset_discovery_indexer; soundpack: Pclap_preset_discovery_soundpack): boolean; cdecl;

    // Query an extension.
    // The returned pointer is owned by the indexer.
    // It is forbidden to call it before provider->init().
    // You can call it within provider->init() call, and after.
    //const void *(CLAP_ABI *get_extension)(const struct clap_preset_discovery_indexer *provider,
    //                                      const char                                  *extension_id);
    get_extension: function(indexer: Pclap_preset_discovery_indexer; extension_id: PAnsiChar): pointer; cdecl;
  end;

// Every methods in this factory must be thread-safe.
// It is encouraged to perform preset indexing in background threads, maybe even in background
// process.
//
// The host may use clap_plugin_invalidation_factory to detect filesystem changes
// which may change the factory's content.
  Pclap_preset_discovery_factory = ^Tclap_preset_discovery_factory;
  Tclap_preset_discovery_factory = record
    // Get the number of preset providers available.
    // [thread-safe]
    //uint32_t(CLAP_ABI *count)(const struct clap_preset_discovery_factory *factory);
    count: function(factory: Pclap_preset_discovery_factory): uint32_t; cdecl;

    // Retrieves a preset provider descriptor by its index.
    // Returns null in case of error.
    // The descriptor must not be freed.
    // [thread-safe]
    //const clap_preset_discovery_provider_descriptor_t *(CLAP_ABI *get_descriptor)(
    //   const struct clap_preset_discovery_factory *factory, uint32_t index);
    get_descriptor: function(factory: Pclap_preset_discovery_factory; index: uint32_t): Pclap_preset_discovery_provider_descriptor; cdecl;

    // Create a preset provider by its id.
    // The returned pointer must be freed by calling preset_provider->destroy(preset_provider);
    // The preset provider is not allowed to use the indexer callbacks in the create method.
    // It is forbidden to call back into the indexer before the indexer calls provider->init().
    // Returns null in case of error.
    // [thread-safe]
    //const clap_preset_discovery_provider_t *(CLAP_ABI *create)(
    //   const struct clap_preset_discovery_factory *factory,
    //   const clap_preset_indexer_t                *indexer,
    //   const char                                 *provider_id);
    create: function(factory: Pclap_preset_discovery_factory; indexer: Pclap_preset_discovery_indexer; provider_id: PAnsiChar): Pclap_preset_discovery_provider; cdecl;
  end;

//factory\draft\plugin-state-converter.h

type
  Tclap_plugin_state_converter_descriptor = record
    clap_version: Tclap_version;

    src_plugin_id: Tclap_universal_plugin_id;
    dst_plugin_id: Tclap_universal_plugin_id;

    id: PAnsiChar;          // eg: "com.u-he.diva-converter", mandatory
    name: PAnsiChar;        // eg: "Diva Converter", mandatory
    vendor: PAnsiChar;      // eg: "u-he"
    version: PAnsiChar;     // eg: 1.1.5
    description: PAnsiChar; // eg: "Official state converter for u-he Diva."
  end;
  Pclap_plugin_state_converter_descriptor = ^Tclap_plugin_state_converter_descriptor;

// This interface provides a mechanism for the host to convert a plugin state and its automation
// points to a new plugin.
//
// This is useful to convert from one plugin ABI to another one.
// This is also useful to offer an upgrade path: from EQ version 1 to EQ version 2.
// This can also be used to convert the state of a plugin that isn't maintained anymore into
// another plugin that would be similar.
type
  Pclap_plugin_state_converter = ^Tclap_plugin_state_converter;
  Tclap_plugin_state_converter = record
    desc: Pclap_plugin_state_converter_descriptor;

    converter_data: pointer;

    // Destroy the converter.
    //void (*destroy)(struct clap_plugin_state_converter *converter);
    destroy: procedure(converter: Pclap_plugin_state_converter); cdecl;

    // Converts the input state to a state usable by the destination plugin.
    //
    // error_buffer is a place holder of error_buffer_size bytes for storing a null-terminated
    // error message in case of failure, which can be displayed to the user.
    //
    // Returns true on success.
    // [thread-safe]
    //bool (*convert_state)(const struct clap_plugin_state_converter *converter,
    //                      const clap_istream_t                     *src,
    //                      const clap_ostream_t                     *dst,
    //                      char                                     *error_buffer,
    //                      size_t                                    error_buffer_size);
    convert_state: function(converter: Pclap_plugin_state_converter; src: Pclap_istream; dst: Pclap_ostream; error_buffer: PAnsiChar; error_buffer_size: size_t): boolean; cdecl;

    // Converts a normalized value.
    // Returns true on success.
    // [thread-safe]
    //bool (*convert_normalized_value)(const struct clap_plugin_state_converter *converter,
    //                                 clap_id                                   src_param_id,
    //                                 double                                    src_normalized_value,
    //                                 clap_id                                  *dst_param_id,
    //                                 double                                   *dst_normalized_value);
    convert_normalized_value: function(converter: Pclap_plugin_state_converter; src_param_id: Tclap_id; src_normalized_value: double;
                                       var dst_param_id: Tclap_id; var dst_normalized_value: double): boolean; cdecl;

    // Converts a plain value.
    // Returns true on success.
    // [thread-safe]
    //bool (*convert_plain_value)(const struct clap_plugin_state_converter *converter,
    //                           clap_id                                   src_param_id,
    //                           double                                    src_plain_value,
    //                           clap_id                                  *dst_param_id,
    //                           double                                   *dst_plain_value);
    convert_plain_value: function(converter: Pclap_plugin_state_converter; src_param_id: Tclap_id; src_plain_value: double;
                                  var dst_param_id: Tclap_id; var dst_plain_value: double): boolean; cdecl;
  end;

// Factory identifier
const
  CLAP_CLAP_CONVERTER_FACTORY_ID = AnsiString('clap.plugin-state-converter-factory/1');

// List all the plugin state converters available in the current DSO.
type
  Pclap_plugin_state_converter_factory = ^Tclap_plugin_state_converter_factory;
  Tclap_plugin_state_converter_factory = record
    // Get the number of converters.
    // [thread-safe]
    //uint32_t (*count)(const struct clap_plugin_state_converter_factory *factory);
    count: function(factory: Pclap_plugin_state_converter_factory): UInt32; cdecl;

    // Retrieves a plugin state converter descriptor by its index.
    // Returns null in case of error.
    // The descriptor must not be freed.
    // [thread-safe]
    //const clap_plugin_state_converter_descriptor_t *(*get_descriptor)(
    //  const struct clap_plugin_state_converter_factory *factory, uint32_t index);
    get_descriptor: function(factory: Pclap_plugin_state_converter_factory; index: UInt32): Pclap_plugin_state_converter_descriptor; cdecl;

    // Create a plugin state converter by its converter_id.
    // The returned pointer must be freed by calling converter->destroy(converter);
    // Returns null in case of error.
    // [thread-safe]
    //clap_plugin_state_converter_t *(*create)(
    //  const struct clap_plugin_state_converter_factory *factory, const char *converter_id);
    create: function(factory: Pclap_plugin_state_converter_factory; converter_id: PAnsiChar): Pclap_plugin_state_converter; cdecl;
  end;

implementation

function clap_version_is_compatible(const v: Tclap_version): boolean;
begin
  result := (v.major >= 1);
end;

end.

