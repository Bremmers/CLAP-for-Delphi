unit clapdefs;

//Delphi translation of the CLAP audio plugin header files from https://github.com/free-audio/clap
//MIT license

interface

uses
  System.SysUtils;

type
  uint16_t = uint16;
  uint32_t = uint32;
  uint64_t = uint64;
  int16_t = int16;
  int32_t = int32;
  int64_t = int64;

//version.h

// This is the major ABI and API design
// Version 0.X.Y correspond to the development stage, API and ABI are not stable
// Version 1.X.Y correspont to the release stage, API and ABI are stable
  Tclap_version = record
    major: uint32_t;
    minor: uint32_t;
    revision: uint32_t;
  end;

const
  CLAP_VERSION_MAJOR = 1;
  CLAP_VERSION_MINOR = 1;
  CLAP_VERSION_REVISION = 4;

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


//events.h

// event header
// must be the first attribute of the event
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
  // - the user double clicks the DAW's stop button in the transport which then stops the sound on
  //   every tracks
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
// In the case of note choke or end events:
// - the velocity is ignored.
// - key and channel are used to match active notes, a value of -1 matches all.
  Tclap_event_note = record
    header: Tclap_event_header;

    note_id: int32_t;  // -1 if unspecified, otherwise >=0
    port_index: int16_t;
    channel: int16_t; // 0..15
    key: int16_t;     // 0..127
    velocity: double; // 0..1
  end;

const
  // with 0 < x <= 4, plain = 20 * log(x)
  CLAP_NOTE_EXPRESSION_VOLUME = 0;

  // pan, 0 left, 0.5 center, 1 right
  CLAP_NOTE_EXPRESSION_PAN = 1;

  // relative tuning in semitone, from -120 to +120
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

    // target a specific note_id, port, key and channel, -1 for global
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

    // target a specific note_id, port, key and channel, -1 for global
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

    // target a specific note_id, port, key and channel, -1 for global
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
  Tclap_event_transport = record
    header: Tclap_event_header;

    flags: uint32_t; // see clap_transport_flags

    song_pos_beats: Tclap_beattime;  // position in beats
    song_pos_seconds: Tclap_sectime; // position in seconds

    tempo: double;     // in bpm
    tempo_inc: double; // tempo increment for each samples and until the next
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

  Tclap_event_midi_sysex = record
    header: Tclap_event_header;

    port_index: uint16_t;
    buffer: pointer; // midi buffer
    size: uint32_t;
  end;

// While it is possible to use a series of midi2 event to send a sysex,
// prefer clap_event_midi_sysex if possible for efficiency.
  Tclap_event_midi2 = record
    header: Tclap_event_header;

    port_index: uint16_t;
    data: array[0..3] of uint32_t;
  end;

// Input event list, events must be sorted by time.
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

// Output event list, events must be sorted by time.
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

    // Input and output events.
    //
    // Events must be sorted by time.
    // The input event list can't be modified.
    in_events: Pclap_input_events;
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
    version: PAnsiChar; // eg: "4.3"

    // Query an extension.
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
    // Once activated the latency and port configuration must remain constant, until deactivation.
    //
    // [main-thread & !active_state]
    //bool (*activate)(const struct clap_plugin *plugin,
    //                 double                    sample_rate,
    //                 uint32_t                  min_frames_count,
    //                 uint32_t                  max_frames_count);
    activate: function(plugin: Pclap_plugin; sample_rate: double; min_frames_count: uint32_t; max_frames_count: uint32_t): boolean; cdecl;
    // [main-thread & active_state]
    //void (*deactivate)(const struct clap_plugin *plugin);
    deactivate: procedure(plugin: Pclap_plugin); cdecl;

    // Call start processing before processing.
    // [audio-thread & active_state & !processing_state]
    //bool (*start_processing)(const struct clap_plugin *plugin);
    start_processing: function(plugin: Pclap_plugin): boolean; cdecl;
    // Call stop processing before sending the plugin to sleep.
    // [audio-thread & active_state & processing_state]
    //void (*stop_processing)(const struct clap_plugin *plugin);
    stop_processing: procedure(plugin: Pclap_plugin); cdecl;

    // - Clears all buffers, performs a full reset of the processing state (filters, oscillators,
    //   enveloppes, lfo, ...) and kills all voices.
    // - The parameter's value remain unchanged.
    // - clap_process.steady_time may jump backward.
    //
    // [audio-thread & active_state]
    //void (*reset)(const struct clap_plugin *plugin);
	  reset: procedure(plugin: Pclap_plugin); cdecl;

    // process audio, events, ...
    // [audio-thread & active_state & processing_state]
    //clap_process_status (*process)(const struct clap_plugin *plugin, const clap_process_t *process);
    process: function(plugin: Pclap_plugin; process: Pclap_process): Tclap_process_status; cdecl;

    // Query an extension.
    // The returned pointer is owned by the plugin.
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
// Non standard features should be formated as follow: "$namespace:$feature"

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


//plugin-factory.h

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


//plugin-invalidation.h

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

const
  CLAP_PLUGIN_INVALIDATION_FACTORY_ID = AnsiString('clap.plugin-invalidation-factory/draft0');

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
//   - %COMMONPROGRAMFILES%/CLAP/
//   - %LOCALAPPDATA%/Programs/Common/CLAP/
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
// Every method must be thread-safe.
  Tclap_plugin_entry = record
    clap_version: Tclap_version;     // initialized to CLAP_VERSION

    // This function must be called first, and can only be called once.
    //
    // It should be as fast as possible, in order to perform a very quick scan of the plugin
    // descriptors.
    //
    // It is forbidden to display graphical user interface in this call.
    // It is forbidden to perform user interaction in this call.
    //
    // If the initialization depends upon expensive computation, maybe try to do them ahead of time
    // and cache the result.
    //
    // If init() returns false, then the host must not call deinit() nor any other clap
    // related symbols from the DSO.
    //bool (*init)(const char *plugin_path);
    init: function (plugin_path: PAnsiChar): boolean; cdecl;

    // No more calls into the DSO must be made after calling deinit().
    //void (*deinit)(void);
    deinit: procedure; cdecl;

    // Get the pointer to a factory. See plugin-factory.h for an example.
    //
    // Returns null if the factory is not provided.
    // The returned pointer must *not* be freed by the caller.
    //const void *(*get_factory)(const char *factory_id);
    get_factory: function(factory_id: PAnsiChar): pointer; cdecl;
  end;
  Pclap_plugin_entry = ^Tclap_plugin_entry;

// Entry point
const
  clap_entry = 'clap_entry';


//stream.h

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
    // only if can resize horizontally and vertically
    preseve_aspect_ratio: boolean;
    aspect_ratio_width: uint32_t;
    aspect_ratio_height: uint32_t;
  end;

// Size (width, height) is in pixels; the corresponding windowing system extension is
// responsible for defining if it is physical pixels or logical pixels.
  Tclap_plugin_gui = record
    // Returns true if the requested gui api is supported
    // [main-thread]
    //bool (*is_api_supported)(const clap_plugin_t *plugin, const char *api, bool is_floating);
    is_api_supported: function(plugin: Pclap_plugin; api: PAnsiChar; is_floating: boolean): boolean; cdecl;

    // Returns true if the plugin has a preferred api.
    // The host has no obligation to honor the plugin preferrence, this is just a hint.
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
    // If is_floating is false, then the plugin has to embbed its window into the parent window, see
    // set_parent().
    //
    // After this call, the GUI may not be visible yet; don't forget to call show().
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
    // Returns true if the scaling could be applied
    // Returns false if the call was ignored, or the scaling could not be applied.
    // [main-thread]
    //bool (*set_scale)(const clap_plugin_t *plugin, double scale);
    set_scale: function(plugin: Pclap_plugin; scale: double): boolean; cdecl;

    // Get the current size of the plugin UI.
    // clap_plugin_gui->create() must have been called prior to asking the size.
    // [main-thread]
    //bool (*get_size)(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height);
    get_size: function(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;

    // Returns true if the window is resizeable (mouse drag).
    // Only for embedded windows.
    // [main-thread]
    //bool (*can_resize)(const clap_plugin_t *plugin);
    can_resize: function(plugin: Pclap_plugin): boolean; cdecl;

    // Returns true if the plugin can provide hints on how to resize the window.
    // [main-thread]
    //bool (*get_resize_hints)(const clap_plugin_t *plugin, clap_gui_resize_hints_t *hints);
    get_resize_hints: function(plugin: Pclap_plugin; var hints: Tclap_gui_resize_hints): boolean; cdecl;

    // If the plugin gui is resizable, then the plugin will calculate the closest
    // usable size which fits in the given size.
    // This method does not change the size.
    //
    // Only for embedded windows.
    // [main-thread]
    //bool (*adjust_size)(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height);
    adjust_size: function(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;

    // Sets the window size. Only for embedded windows.
    // [main-thread]
    //bool (*set_size)(const clap_plugin_t *plugin, uint32_t width, uint32_t height);
    set_size: function(plugin: Pclap_plugin; width: uint32_t; height: uint32_t): boolean; cdecl;

    // Embbeds the plugin window into the given window.
    // [main-thread & !floating]
    //bool (*set_parent)(const clap_plugin_t *plugin, const clap_window_t *window);
    set_parent: function(plugin: Pclap_plugin; window: Pclap_window): boolean; cdecl;

    // Set the plugin floating window to stay above the given window.
    // [main-thread & floating]
    //bool (*set_transient)(const clap_plugin_t *plugin, const clap_window_t *window);
    set_transient: function(plugin: Pclap_plugin; window: Pclap_window): boolean; cdecl;

    // Suggests a window title. Only for floating windows.
    // [main-thread & floating]
    //void (*suggest_title)(const clap_plugin_t *plugin, const char *title);
    suggest_title: procedure(plugin: Pclap_plugin; title: PAnsiChar); cdecl;

    // Show the window.
    // [main-thread]
    //bool (*show)(const clap_plugin_t *plugin);
    show: function(plugin: Pclap_plugin): boolean; cdecl;

    // Hide the window, this method does not free the resources, it just hides
    // the window content. Yet it may be a good idea to stop painting timers.
    // [main-thread]
    //bool (*hide)(const clap_plugin_t *plugin);
    hide: function(plugin: Pclap_plugin): boolean; cdecl;
  end;
  Pclap_plugin_gui = ^Tclap_plugin_gui;

  clap_host_gui = record
    // The host should call get_resize_hints() again.
    // [thread-safe]
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
    // [thread-safe] */
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


//state.h

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


//ext\draft\state-context.h

/// @page state-context extension
/// @brief extended state handling
///
/// This extension lets the host save and load the plugin state with different semantics depending
/// on the context.
///
/// Briefly, when loading a preset or duplicating a device, the plugin may want to partially load
/// the state and initialize certain things differently.
///
/// Save and Load operations may have a different context.
/// All three operations should be equivalent:
/// 1. clap_plugin_state_context.load(clap_plugin_state.save(), CLAP_STATE_CONTEXT_FOR_PRESET)
/// 2. clap_plugin_state.load(clap_plugin_state_context.save(CLAP_STATE_CONTEXT_FOR_PRESET))
/// 3. clap_plugin_state_context.load(
///        clap_plugin_state_context.save(CLAP_STATE_CONTEXT_FOR_PRESET),
///        CLAP_STATE_CONTEXT_FOR_PRESET)
///
/// If the plugin implements CLAP_EXT_STATE_CONTEXT then it is mandatory to also implement
/// CLAP_EXT_STATE.

const
  CLAP_EXT_STATE_CONTEXT = AnsiString('clap.state-context.draft/1');

  // suitable for duplicating a plugin instance
  CLAP_STATE_CONTEXT_FOR_DUPLICATE = 1;

  // suitable for loading a state as a preset
  CLAP_STATE_CONTEXT_FOR_PRESET = 2;

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
    // [main-thread]
    //bool (*register_timer)(const clap_host_t *host, uint32_t period_ms, clap_id *timer_id);
    register_timer: function(host: Pclap_host; period_ms: uint32_t; var timer_id: Tclap_id): boolean; cdecl;

    // [main-thread]
    //bool (*unregister_timer)(const clap_host_t *host, clap_id timer_id);
    unregister_timer: function(host: Pclap_host; timer_id: Tclap_id): boolean; cdecl;
  end;


//ext\audio-ports.h

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
    // This filed can be compared against:
    // - CLAP_PORT_MONO
    // - CLAP_PORT_STEREO
    // - CLAP_PORT_SURROUND (defined in the surround extension)
    // - CLAP_PORT_AMBISONIC (defined in the ambisonic extension)
    // - CLAP_PORT_CV (defined in the cv extension)
    //
    // An extension can provide its own port type and way to inspect the channels.
    port_type: PAnsiChar;

    // in-place processing: allow the host to use the same buffer for input and output
    // if supported set the pair port id.
    // if not supported set to CLAP_INVALID_ID
    in_place_pair: Tclap_id;
  end;

// The audio ports scan has to be done while the plugin is deactivated.
  Tclap_plugin_audio_ports = record
    // number of ports, for either input or output
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin, bool is_input);
    count: function(plugin: Pclap_plugin; is_input: boolean): uint32_t; cdecl;

    // get info about about an audio port.
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
    // number of ports, for either input or output
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin, bool is_input);
    count: function(plugin: Pclap_plugin; is_input: boolean): uint32_t; cdecl;

    // get info about about a note port.
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
/// @ref clap_plugin_params.value().
///
/// There are two options to communicate parameter value changes, and they are not concurrent.
/// - send automation points during clap_plugin.process()
/// - send automation points during clap_plugin_params.flush(), for parameter changes
///   without processing audio
///
/// When the plugin changes a parameter value, it must inform the host.
/// It will send @ref CLAP_EVENT_PARAM_VALUE event during process() or flush().
/// If the user is adjusting the value, don't forget to mark the begining and end
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
///   The plugin is resonsible for updating both its audio processor and its gui.
///
/// II. Turning a knob on the DAW interface
/// - the host will send an automation event to the plugin via a process() or flush()
///
/// III. Turning a knob on the Plugin interface
/// - the plugin is responsible for sending the parameter value to its audio processor
/// - call clap_host_params->request_flush() or clap_host->request_process().
/// - when the host calls either clap_plugin->process() or clap_plugin_params->flush(),
///   send an automation event and don't forget to set begin_adjust,
///   end_adjust and should_record flags
///
/// IV. Turning a knob via automation
/// - host sends an automation point during clap_plugin->process() or clap_plugin_params->flush().
/// - the plugin is responsible for updating its GUI
///
/// V. Turning a knob via plugin's internal MIDI mapping
/// - the plugin sends a CLAP_EVENT_PARAM_SET output event, set should_record to false
/// - the plugin is responsible to update its GUI
///
/// VI. Adding or removing parameters
/// - if the plugin is activated call clap_host->restart()
/// - once the plugin isn't active:
///   - apply the new state
///   - if a parameter is gone or is created with an id that may have been used before,
///     call clap_host_params.clear(host, param_id, CLAP_PARAM_CLEAR_ALL)
///   - call clap_host_params->rescan(CLAP_PARAM_RESCAN_ALL)

const
  CLAP_EXT_PARAMS = AnsiString('clap.params');

  // Is this param stepped? (integer values only)
  // if so the double value is converted to integer using a cast (equivalent to trunc).
  CLAP_PARAM_IS_STEPPED = 1 shl 0;

  // Useful for for periodic parameters like a phase
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

type
  Tclap_param_info_flags = uint32_t;

///* This describes a parameter */
  Tclap_param_info = record
    // stable parameter identifier, it must never change.
    id: Tclap_id;

    flags: Tclap_param_info_flags;

    // This value is optional and set by the plugin.
    // Its purpose is to provide a fast access to the
    // plugin parameter object by caching its pointer.
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
    // where findParameter() is a function the plugin implements
    // to map parameter ids to internal objects.
    //
    // Important:
    //  - The cookie is invalidated by a call to
    //    clap_host_params->rescan(CLAP_PARAM_RESCAN_ALL) or when the plugin is
    //    destroyed.
    //  - The host will either provide the cookie as issued or nullptr
    //    in events addressing parameters.
    //  - The plugin must gracefully handle the case of a cookie
    //    which is nullptr.
    //  - Many plugins will process the parameter events more quickly if the host
    //    can provide the cookie in a faster time than a hashmap lookup per param
    //    per event.
    cookie: pointer;

    // the display name
    name: array[0..CLAP_NAME_SIZE - 1] of byte;

    // the module path containing the param, eg:"oscillators/wt1"
    // '/' will be used as a separator to show a tree like structure.
    module: array[0..CLAP_PATH_SIZE - 1] of byte;

    min_value: double;     // minimum plain value
    max_value: double;     // maximum plain value
    default_value: double; // default plain value
  end;
  Pclap_param_info = ^Tclap_param_info;

  Tclap_plugin_params = record
    // Returns the number of parameters.
    // [main-thread]
    //uint32_t (*count)(const clap_plugin_t *plugin);
    count: function(plugin: Pclap_plugin): uint32_t; cdecl;

    // Copies the parameter's info to param_info and returns true on success.
    // [main-thread]
    //bool (*get_info)(const clap_plugin_t *plugin,
    //                 uint32_t              param_index,
    //                 clap_param_info_t   *param_info);
    get_info: function(plugin: Pclap_plugin; param_index: uint32_t; var param_info: Tclap_param_info): boolean; cdecl;

    // Gets the parameter plain value.
    // [main-thread]
    //bool (*get_value)(const clap_plugin_t *plugin, clap_id param_id, double *value);
    get_value: function(plugin: Pclap_plugin; param_id: Tclap_id; var value: double): boolean; cdecl;

    // Formats the display text for the given parameter value.
    // The host should always format the parameter value to text using this function
    // before displaying it to the user.
    // [main-thread]
    //bool (*value_to_text)(
    //  const clap_plugin_t *plugin, clap_id param_id, double value, char *display, uint32_t size);
    value_to_text: function(plugin: Pclap_plugin; param_id: Tclap_id; value: double; display: PAnsiChar; size: uint32_t): boolean; cdecl;

    // Converts the display text to a parameter value.
    // [main-thread]
    //bool (*text_to_value)(const clap_plugin_t *plugin,
    //                     clap_id              param_id,
    //                     const char          *display,
    //                     double              *value);
    text_to_value: function(plugin: Pclap_plugin; param_id: Tclap_id; display: PAnsiChar; var value: double): boolean; cdecl;

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
    changed: procedure(host: Pclap_host); cdecl
  end;
  Pclap_host_note_name = ^Tclap_host_note_name;


//ext\latency.h

const
  CLAP_EXT_LATENCY = AnsiString('clap.latency');

// The audio ports scan has to be done while the plugin is deactivated.
type
  Tclap_plugin_latency = record
    // Returns the plugin latency.
    // [main-thread]
    //uint32_t (*get)(const clap_plugin_t *plugin);
    get: function(plugin: Pclap_plugin): uint32_t; cdecl;
  end;
  Pclap_plugin_latency = ^Tclap_plugin_latency;

  Tclap_host_latency = record
    // Tell the host that the latency changed.
    // The latency is only allowed to change if the plugin is deactivated.
    // If the plugin is activated, call host->request_restart()
    // [main-thread]
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
    // Returns true if the plugin has an hard requirement to process in real-time.
    // This is especially useful for plugin acting as a proxy to an hardware device.
    // [main-thread]
    //bool (*has_hard_realtime_requirement)(const clap_plugin_t *plugin);
    has_hard_realtime_requirement: function(plugin: Pclap_plugin): boolean; cdecl;

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
///    It is usually the thread on which the GUI receives its events.
///    It isn't a realtime thread, yet this thread needs to respond fast enough to user interaction,
///    so it is recommended to run long and expensive tasks such as preset indexing or asset loading
///    in dedicated background threads.
///
/// audio-thread:
///    This thread is used for realtime audio processing. Its execution should be as deterministic
///    as possible to meet the audio interface's deadline (can be <1ms). In other words, there is a
///    known set of operations that should be avoided: malloc() and free(), mutexes (spin mutexes
///    are worse), I/O, waiting, ...
///    The audio-thread is something symbolic, there isn't one OS thread that remains the
///    audio-thread for the plugin lifetime. As you may guess, the host is likely to have a
///    thread pool and the plugin.process() call may be scheduled on different OS threads over time.
///    The most important thing is that there can't be two audio-threads at the same time. All the
///    functions marked with [audio-thread] **ARE NOT CONCURRENT**. The host may mark any OS thread,
///    including the main-thread as the audio-thread, as long as it can guarentee that only one OS
///    thread is the audio-thread at a time. The audio-thread can be seen as a concurrency guard for
///    all functions marked with [audio-thread].

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


//ext\draft\context-menu.h

// This extension lets the host and plugin exchange menu items and let the plugin ask the host to
// show its context menu.

const
   CLAP_EXT_CONTEXT_MENU = AnsiString('clap.context-menu.draft/0');

// There can be different target kind for a context menu
   CLAP_CONTEXT_MENU_TARGET_KIND_GLOBAL = 0;
   CLAP_CONTEXT_MENU_TARGET_KIND_PARAM = 1;
   // TODO: kind trigger once the trigger ext is marked as stable

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
    // entry_data type is determined by entry_kind.
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
    // [main-thread]
    //bool(CLAP_ABI *populate)(const clap_plugin_t               *plugin,
    //                         const clap_context_menu_target_t  *target,
    //                         const clap_context_menu_builder_t *builder);
    populate: function(plugin: Pclap_plugin; target: Pclap_context_menu_target; builder: Pclap_context_menu_builder): boolean; cdecl;

    // Performs the given action, which was previously provided to the host via populate().
    // If target is null, assume global context
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
    // [main-thread]
    //bool(CLAP_ABI *populate)(const clap_host_t                 *host,
    //                         const clap_context_menu_target_t  *target,
    //                         const clap_context_menu_builder_t *builder);
    populate: function(host: Pclap_host; target: Pclap_context_menu_target; builder: Pclap_context_menu_builder): boolean; cdecl;

    // Performs the given action, which was previously provided to the plugin via populate().
    // If target is null, assume global context
    // [main-thread]
    //bool(CLAP_ABI *perform)(const clap_host_t                *host,
    //                        const clap_context_menu_target_t *target,
    //                        clap_id action_id);
    perform: function(host: Pclap_host; target: Pclap_context_menu_target; action_id: Tclap_id): boolean; cdecl;

    // Returns true if the host can display a popup menu for the plugin.
    // This may depends upon the current windowing system used to display the plugin, so the
    // return value is invalidated after creating the plugin window.
    // [main-thread]
    //bool(CLAP_ABI *can_popup)(const clap_host_t *host);
    can_popup: function(host: Pclap_host): boolean; cdecl;

    // Shows the host popup menu for a given parameter.
    // If the plugin is using embedded GUI, then x and y are relative to the plugin's window,
    // otherwise they're absolute coordinate, and screen index might be set accordingly.
    // If target is null, assume global context
    // [main-thread]
    //bool(CLAP_ABI *popup)(const clap_host_t                *host,
    //                      const clap_context_menu_target_t *target,
    //                      int32_t                           screen_index,
    //                      int32_t                           x,
    //                      int32_t                           y);
    popup: function(host: Pclap_host; target: Pclap_context_menu_target; screen_index, x, y: int32): boolean; cdecl;
  end;
  Pclap_host_context_menu = ^Tclap_host_context_menu;


//ext\draft\param-indication.h

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
  CLAP_EXT_PARAM_INDICATION = AnsiString('clap.param-indication.draft/4');

  // The host doesn't have an automation for this parameter
  CLAP_PARAM_INDICATION_AUTOMATION_NONE = 0;

  // The host has an automation for this parameter, but it isn't playing it
  CLAP_PARAM_INDICATION_AUTOMATION_PRESENT = 1;

  // The host is playing an automation for this parameter
  CLAP_PARAM_INDICATION_AUTOMATION_PLAYING = 2;

  // The host is recording an automation on this parameter
  CLAP_PARAM_INDICATION_AUTOMATION_RECORDING = 3;

  // The host should play an automation for this parameter, but the user has started to ajust this
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


//ext\draft\track-info.h

// This extensions let the plugin query info about the track it's in.
// It is useful when the plugin is created, to initialize some parameters (mix, dry, wet)
// and pick a suitable configuartion regarding audio port type and channel count.
const
  CLAP_EXT_TRACK_INFO = AnsiString('clap.track-info.draft/1');
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
    // availabe if flags contain CLAP_TRACK_INFO_HAS_AUDIO_CHANNEL
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
  CLAP_EXT_TRANSPORT_CONTROL = AnsiString('clap.transport-control.draft/0');

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


implementation

function clap_version_is_compatible(const v: Tclap_version): boolean;
begin
  result := (v.major >= 1);
end;

end.

