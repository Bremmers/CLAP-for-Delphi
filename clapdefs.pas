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

//typedef struct clap_version {
//   // This is the major ABI and API design
//   // Version 0.X.Y correspond to the development stage, API and ABI are not stable
//   // Version 1.X.Y correspont to the release stage, API and ABI are stable
//   alignas(4) uint32_t major;
//   alignas(4) uint32_t minor;
//   alignas(4) uint32_t revision;
//} clap_version_t;
  Tclap_version = record
    major: uint32_t;
    minor: uint32_t;
    revision: uint32_t;
  end;

const
  CLAP_VERSION_MAJOR = 0;
  CLAP_VERSION_MINOR = 18;
  CLAP_VERSION_REVISION = 0;

  CLAP_VERSION: Tclap_version = (
    major: CLAP_VERSION_MAJOR;
    minor: CLAP_VERSION_MINOR;
    revision: CLAP_VERSION_REVISION;
  );

//// For version 0, we require the same minor version because
//// we may still break the ABI at this point
//static CLAP_CONSTEXPR inline bool clap_version_is_compatible(const clap_version_t v) {
//   return v.major == CLAP_VERSION_MAJOR && v.minor == CLAP_VERSION_MINOR;
//}
function clap_version_is_compatible(const v: Tclap_version): boolean; inline;


//string-sizes.h

const
  CLAP_NAME_SIZE = 256;
  CLAP_MODULE_SIZE = 512;
  CLAP_KEYWORDS_SIZE = 256;
  CLAP_PATH_SIZE = 4096;


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


//events.h

// event header
// must be the first attribute of the event
type
  Tclap_event_header = record
    size: uint32_t;      // event size including this header, eg: sizeof (clap_event_note)
    time: uint32_t;      // time at which the event happens
    space_id: uint16_t;  // event space, see clap_host_event_registry
    &type: uint16_t;     // event type
    flags: uint32_t;     // see clap_event_flags
  end;
  Pclap_event_header = ^Tclap_event_header;

// The clap core event space
const
  CLAP_CORE_EVENT_SPACE_ID = 0;

//enum clap_event_flags {
  // indicate a live momentary event
  CLAP_EVENT_IS_LIVE = 1 shl 0;

  // live user adjustment begun
  CLAP_EVENT_BEGIN_ADJUST = 1 shl 1;

  // live user adjustment ended
  CLAP_EVENT_END_ADJUST = 1 shl 2;

  // should record this event be recorded?
  CLAP_EVENT_SHOULD_RECORD = 1 shl 3;

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
//enum {
  // NOTE_ON and NOTE_OFF represents a key pressed and key released event.
  //
  // NOTE_CHOKE is meant to choke the voice(s), like in a drum machine when a closed hihat
  // chokes an open hihat.
  //
  // NOTE_END is sent by the plugin to the host, when a voice terminates.
  // When using polyphonic modulations, the host has to start voices for its modulators.
  // This message helps the host to track the plugin's voice management.
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

  CLAP_EVENT_TRANSPORT = 7;  // update the transport info; clap_event_transport
  CLAP_EVENT_MIDI = 8;       // raw midi event; clap_event_midi
  CLAP_EVENT_MIDI_SYSEX = 9; // raw midi sysex event; clap_event_midi_sysex
  CLAP_EVENT_MIDI2 = 10;     // raw midi 2 event; clap_event_midi2

type
  Tclap_event_type = int32_t;

//
// Note on, off, end and choke events.
// In the case of note choke or end events:
// - the velocity is ignored.
// - key and channel are used to match active notes, a value of -1 matches all.
//
  Tclap_event_note = record
    header: Tclap_event_header;

    port_index: int16_t;
    key: int16_t;     // 0..127
    channel: int16_t; // 0..15
    velocity: double; // 0..1
  end;

const
  // x >= 0, use 20 * log(4 * x)
  CLAP_NOTE_EXPRESSION_VOLUME = 0;

  // pan, 0 left, 0.5 center, 1 right
  CLAP_NOTE_EXPRESSION_PAN = 1;

  // relative tuning in semitone, from -120 to +120
  CLAP_NOTE_EXPRESSION_TUNING = 2;

  // 0..1
  CLAP_NOTE_EXPRESSION_VIBRATO = 3;
  CLAP_NOTE_EXPRESSION_BRIGHTNESS = 4;
  CLAP_NOTE_EXPRESSION_BREATH = 5;
  CLAP_NOTE_EXPRESSION_PRESSURE = 6;
  CLAP_NOTE_EXPRESSION_TIMBRE = 7;

   // TODO...
type
  Tclap_note_expression = int32_t;

  Tclap_event_note_expression  = record
    header: Tclap_event_header;

    expression_id: Tclap_note_expression;

    // target a specific port, key and channel, -1 for global
    port_index: int16_t;
    key: int16_t;
    channel: int16_t;

    value: double; // see expression for the range
  end;

  Tclap_event_param_value = record
    header: Tclap_event_header;

    // target parameter
    param_id: Tclap_id; // @ref clap_param_info.id
    cookie: pointer;    // @ref clap_param_info.cookie

    // target a specific port, key and channel, -1 for global
    port_index: int16_t;
    key: int16_t;
    channel: int16_t;

    value: double;
  end;

//typedef struct clap_event_param_mod {
//   alignas(4) clap_event_header_t header;
//
//   // target parameter
//   alignas(4) clap_id param_id; // @ref clap_param_info.id
//   void *cookie;                // @ref clap_param_info.cookie
//
//   // target a specific port, key and channel, -1 for global
//   alignas(2) int16_t port_index;
//   alignas(2) int16_t key;
//   alignas(2) int16_t channel;
//
//   alignas(8) double amount; // modulation amount
//} clap_event_param_mod_t;

//enum clap_transport_flags {
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

    tsig_num: int16_t;   // time signature numerator
    tsig_denom: int16_t; // time signature denominator
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

    //uint32_t (*size)(const struct clap_input_events *list);
    size: function(list: Pclap_input_events): uint32_t; cdecl;

    // Don't free the return event, it belongs to the list
    //const clap_event_header_t *(*get)(const struct clap_input_events *list, uint32_t index);
    get: function(list: Pclap_input_events; index: uint32_t): Pclap_event_header; cdecl;
  end;

// Output event list, events must be sorted by time.
  Pclap_output_events = ^Tclap_output_events;
  Tclap_output_events = record
    ctx: TObject; // reserved pointer for the list

    // Pushes a copy of the event
    //void (*push_back)(const struct clap_output_events *list, const clap_event_header_t *event);
    push_back: procedure(list: Pclap_output_events; event: Pclap_event_header); cdecl;
  end;


//audio-buffer.h

type
// Sample code for reading a stereo buffer:
//
// bool isLeftConstant = (buffer->constant_mask & (1 << 0)) != 0;
// bool isRightConstant = (buffer->constant_mask & (1 << 1)) != 0;
//
// for (int i = 0; i < N; ++i) {
//    float l = data32[0][i * isLeftConstant];
//    float r = data32[1][i * isRightConstant];
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
    latency: uint32_t;       // latency from/to the audio interface
    constant_mask: uint64_t; // mask & (1 << N) to test if channel N is constant
  end;


//process.h

const
  // Processing failed. The output buffer must be discarded.
  CLAP_PROCESS_ERROR = 0;

  // Processing succeed, keep processing.
  CLAP_PROCESS_CONTINUE = 1;

  // Processing succeed, keep processing if the output is not quiet.
  CLAP_PROCESS_CONTINUE_IF_NOT_QUIET = 2;

  // Processing succeed, but no more processing is required,
  // until next event or variation in audio input.
  CLAP_PROCESS_SLEEP = 3;

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
    // by clap_plugin_audio_ports->get_count().
    // The index maps to clap_plugin_audio_ports->get_info().
    //
    // If a plugin does not implement clap_plugin_audio_ports,
    // then it gets a default stereo input and output.
    audio_inputs: pointer { Pclap_audio_buffer_t };
    audio_outputs: pointer { Pclap_audio_buffer_t };
    audio_inputs_count: uint32_t;
    audio_outputs_count: uint32_t;

    // Input and output events.
    //
    // Events must be sorted by time.
    // The input event list can't be modified.
    //
    // If a plugin does not implement clap_plugin_note_ports,
    // then it gets a default note input and output.
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
    version: PAnsiChar; // eg: "3.3.8"

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

    id: PAnsiChar;          // eg: "com.u-he.diva"
    name: PAnsiChar;        // eg: "Diva"
    vendor: PAnsiChar;      // eg: "u-he"
    url: PAnsiChar;         // eg: "https://u-he.com/products/diva/"
    manual_url: PAnsiChar;  // eg: "https://dl.u-he.com/manuals/plugins/diva/Diva-user-guide.pdf"
    support_url: PAnsiChar; // eg: "https://u-he.com/support/"
    version: PAnsiChar;     // eg: "1.4.4"
    description: PAnsiChar; // eg: "The spirit of analogue"

    // Arbitrary list of keywords.
    // They can be matched by the host search engine and used to classify the plugin.
    //
    // The array of pointers must be null terminated.
    //
    // Some pre-defined keywords:
    // - "instrument", "audio_effect", "note_effect", "analyzer"
    // - "mono", "stereo", "surround", "ambisonic"
    // - "distortion", "compressor", "limiter", "transient"
    // - "equalizer", "filter", "de-esser"
    // - "delay", "reverb", "chorus", "flanger"
    // - "tool", "utility", "glitch"
    //
    // - "win32-dpi-aware" informs the host that this plugin is dpi-aware on Windows
    //
    // Some examples:
    // "equalizer;analyzer;stereo;mono"
    // "compressor;analog;character;mono"
    // "reverb;plate;stereo"
    // "reverb;spring;surround"
    // "kick;analog;808;roland;drum;mono;instrument"
    // "instrument;chiptune;gameboy;nintendo;sega;mono"
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
    // It is not required to deactivate the plugin prior to this call. */}
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


//plugin-factory.h

const
  CLAP_PLUGIN_FACTORY_ID = AnsiString('clap.plugin-factory');

type
  Pclap_plugin_factory = ^Tclap_plugin_factory;
// Every methods must be thread-safe.
// It is very important to be able to scan the plugin as quickly as possible.
//
// If the content of the factory may change due to external events, like the user installed
  Tclap_plugin_factory = record
   { Get the number of plugins available.
    * [thread-safe] }
    //uint32_t (*get_plugin_count)(const struct clap_plugin_factory *factory);
    get_plugin_count: function(factory: Pclap_plugin_factory): uint32_t; cdecl;

   { Retrieves a plugin descriptor by its index.
    * Returns null in case of error.
    * The descriptor must not be freed.
    * [thread-safe] }
    //const clap_plugin_descriptor_t *(*get_plugin_descriptor)(
    //  const struct clap_plugin_factory *factory, uint32_t index);
    get_plugin_descriptor: function(factory: Pclap_plugin_factory; index: uint32_t): Pclap_plugin_descriptor; cdecl;

   { Create a clap_plugin by its plugin_id.
    * The returned pointer must be freed by calling plugin->destroy(plugin);
    * The plugin is not allowed to use the host callbacks in the create method.
    * Returns null in case of error.
    * [thread-safe] }
    //const clap_plugin_t *(*create_plugin)(const struct clap_plugin_factory *factory,
    //                                      const clap_host_t                *host,
    //                                      const char                       *plugin_id);
    create_plugin: function(factory: Pclap_plugin_factory; host: Pclap_host; plugin_id: PAnsiChar): Pclap_plugin; cdecl;
  end;


//plugin-invalidation.h

type
  Tclap_plugin_invalidation_source = record
    // Directory containing the file(s) to scan
    directory: PAnsiChar;
    // globing pattern, in the form *.dll
    filename_glob: PAnsiChar;
    // should the directory be scanned recursively?
    recursive_scan: boolean;
  end;
  Pclap_plugin_invalidation_source = ^Tclap_plugin_invalidation_source;

const
  CLAP_PLUGIN_INVALIDATION_FACTORY_ID = AnsiString('clap.plugin-invalidation-factory');

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
    // plugin_entry scan the set of plugins available.
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
//   - /usr/lib/clap/
//   - ~/.clap
//     `-> ~/.local/lib/clap/ is considered, see https://github.com/free-audio/clap/issues/46
//
// Windows
//   - %CommonFilesFolder%/CLAP/
//   - %LOCALAPPDATA%/Programs/Common/VST3/
//
// MacOS
//   - /Library/Audio/Plug-Ins/CLAP
//   - ~/Library/Audio/Plug-Ins/CLAP
//
// Every methods must be thread-safe.
  Tclap_plugin_entry = record
    clap_version: Tclap_version;     // initialized to CLAP_VERSION

    // This function must be called fist, and can only be called once.
    //
    // It should be as fast as possible, in order to perform very quick scan of the plugin
    // descriptors.
    //
    // It is forbidden to display graphical user interface in this call.
    // It is forbidden to perform user inter-action in this call.
    //
    // If the initialization depends upon expensive computation, maybe try to do them ahead of time
    // and cache the result.
    //bool (*init)(const char *plugin_path);
    init: function (plugin_path: PAnsiChar): boolean; cdecl;

    // No more calls into the DSO must be made after calling deinit().
    //void (*deinit)(void);
    deinit: procedure; cdecl;

    // Get the pointer to a factory.
    // See plugin-factory.h, vst2-converter.h ...
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

    {* returns the number of bytes read.
    * 0 for end of file.
    * -1 on error. */}
    //int64_t (*read)(struct clap_istream *stream, void *buffer, uint64_t size);
    read: function(stream: Pclap_istream; buffer: pointer; size: uint64_t): int64_t; cdecl;
  end;

  Pclap_ostream = ^Tclap_ostream;
  Tclap_ostream = record
    ctx: TObject; // reserved pointer for the stream

    // returns the number of bytes written.
    // -1 on error. */}
    //int64_t (*write)(struct clap_ostream *stream, const void *buffer, uint64_t size);
    write: function(stream: Pclap_ostream; buffer: pointer; size: uint64_t): int64_t; cdecl;
  end;


//ext\gui.h

/// @page GUI
///
/// This extension is splet in two interfaces:
/// - `gui` which is the generic part
/// - `gui_XXX` which is the platform specific interfaces; @see clap_gui_win32.
///
/// Showing the GUI works as follow:
/// 1. clap_plugin_gui->create(), allocates gui resources
/// 2. clap_plugin_gui->set_scale()
/// 3. clap_plugin_gui->get_size(), gets initial size
/// 4. clap_plugin_gui_win32->embed(), or any other platform specific interface
/// 5. clap_plugin_gui->show()
/// 6. clap_plugin_gui->hide()/show() ...
/// 7. clap_plugin_gui->destroy() when done with the gui
///
/// Resizing the window:
/// 1. Only possible if clap_plugin_gui->can_resize() returns true
/// 2. Mouse drag -> new_size
/// 3. clap_plugin_gui->round_size(new_size) -> working_size
/// 4. clap_plugin_gui->set_size(working_size)

const
  CLAP_EXT_GUI = AnsiString('clap.gui');

type
  Tclap_plugin_gui = record
    // Create and allocate all resources necessary for the gui.
    // After this call, the GUI is ready to be shown but it is not yet visible.
    // [main-thread]
    //bool (*create)(const clap_plugin_t *plugin);
    create: function(plugin: Pclap_plugin): boolean; cdecl;

    // Free all resources associated with the gui.
    // [main-thread]
    //void (*destroy)(const clap_plugin_t *plugin);
    destroy: procedure(plugin: Pclap_plugin); cdecl;

    // Set the absolute GUI scaling factor, and override any OS info.
    // If the plugin does not provide this function, then it should work out the scaling factor
    // itself by querying the OS directly.
    //
    // Return false if the plugin can't apply the scaling; true on success.
    // [main-thread,optional]
    //bool (*set_scale)(const clap_plugin_t *plugin, double scale);
    set_scale: function(plugin: Pclap_plugin; scale: double): boolean; cdecl;

    // Get the current size of the plugin UI, with the scaling applied.
    // clap_plugin_gui->create() must have been called prior to asking the size.
    // [main-thread]
    //bool (*get_size)(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height);
    get_size: function(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t): boolean; cdecl;

    // [main-thread]
    //bool (*can_resize)(const clap_plugin_t *plugin);
    can_resize: function(plugin: Pclap_plugin): boolean; cdecl;

    // If the plugin gui is resizable, then the plugin will calculate the closest
    // usable size to the given arguments.
    // The scaling is applied.
    // This method does not change the size.
    //
    // [main-thread]
    //void (*round_size)(const clap_plugin_t *plugin, uint32_t *width, uint32_t *height);
    round_size: procedure(plugin: Pclap_plugin; var width: uint32_t; var height: uint32_t); cdecl;

    // Sets the window size
    // Returns true if the size is supported.
    // [main-thread]
    //bool (*set_size)(const clap_plugin_t *plugin, uint32_t width, uint32_t height);
    set_size: function(plugin: Pclap_plugin; width: uint32_t; height: uint32_t): boolean; cdecl;

    // Show the window.
    // [main-thread]
    //void (*show)(const clap_plugin_t *plugin);
    show: procedure(plugin: Pclap_plugin); cdecl;

    // Hide the window, this method do not free the resources, it just hides
    // the window content. Yet it maybe a good idea to stop painting timers.
    // [main-thread]
    //void (*hide)(const clap_plugin_t *plugin);
    hide: procedure(plugin: Pclap_plugin); cdecl;
  end;
  Pclap_plugin_gui = ^Tclap_plugin_gui;

  clap_host_gui = record
    // Request the host to resize the client area to width, height.
    // Return true on success, false otherwise.
    // [thread-safe]}
    //bool (*resize)(const clap_host_t *host, uint32_t width, uint32_t height);
    request_resize: function(host: Pclap_host; width: uint32_t; height: uint32_t): boolean; cdecl;

    // Request the host to show the plugin gui.
    // Return true on success, false otherwise.
    // [main-thread] */
    //bool (*request_show)(const clap_host_t *host);
    request_show: function(host: Pclap_host): boolean; cdecl;

    // Request the host to hide the plugin gui.
    // Return true on success, false otherwise.
    // [main-thread] */
    //bool (*request_hide)(const clap_host_t *host);
    request_hide: function(host: Pclap_host): boolean; cdecl;
  end;


{$IFDEF MSWINDOWS}
//ext\gui-win32.h

const
  CLAP_EXT_GUI_WIN32 = AnsiString('clap.gui-win32');

// we don't want to include windows.h from this file.
type
  Tclap_hwnd = pointer;

  Tclap_plugin_gui_win32 = record
    // [main-thread]
    // bool (*attach)(const clap_plugin_t *plugin, clap_hwnd window);
    attach: function(plugin: Pclap_plugin; window: Tclap_hwnd): boolean; cdecl;
  end;
  Pclap_plugin_gui_win32 = ^Tclap_plugin_gui_win32;
{$ENDIF}


{$IFDEF MACOS}
//ext\gui-cocoa.h

const
  CLAP_EXT_GUI_COCOA = AnsiString('clap.gui-cocoa');

type
  Tclap_plugin_gui_cocoa = record
    // [main-thread]
    //bool (*attach)(const clap_plugin_t *plugin, void *nsView);
    attach: function(plugin: Pclap_plugin; nsView: pointer): boolean; cdecl;
  end;
  Pclap_plugin_gui_cocoa = ^Tclap_plugin_gui_cocoa;
{$ENDIF}


//ext\log.h

const
  CLAP_EXT_LOG = AnsiString('clap.log');

  CLAP_LOG_DEBUG = 0;
  CLAP_LOG_INFO = 1;
  CLAP_LOG_WARNING = 2;
  CLAP_LOG_ERROR = 3;
  CLAP_LOG_FATAL = 4;

  // Those severities should be used to report misbehaviour.
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
    //bool (*save)(const clap_plugin_t *plugin, clap_ostream_t *stream);
    save: function(plugin: Pclap_plugin; stream: Pclap_ostream): boolean; cdecl;

    // Loads the plugin state from stream.
    // Returns true if the state was correctly restored.
    // [main-thread]
    //bool (*load)(const clap_plugin_t *plugin, clap_istream_t *stream);
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
//} clap_host_timer_support_t;


//ext\audio-ports.h

/// This extension provides a way for the plugin to describe its current audio ports.
///
/// If the plugin does not implement this extension, it will have a default 32 bits stereo input and output.
/// This makes 32 bit support a requirement for both plugin and host.
///
/// The plugin is only allowed to change its ports configuration while it is deactivated.

const
  CLAP_EXT_AUDIO_PORTS = AnsiString('clap.audio-ports');
  CLAP_PORT_MONO = AnsiString('mono');
  CLAP_PORT_STEREO = AnsiString('stereo');

  // This port main audio input or output.
  // There can be only one main input and main output.
  CLAP_AUDIO_PORT_IS_MAIN = 1 shl 0;

  // The prefers 64 bits audio with this port.
  CLAP_AUDIO_PORTS_PREFERS_64BITS = 1 shl 1;
type
  Tclap_audio_port_info = record
    id: Tclap_id;                // stable identifier
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
type
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
  // The ports have changed, the host shall perform a full scan of the ports.
  // This flag can only be used if the plugin is not active.
  // If the plugin active, call host->request_restart() and then call rescan()
  // when the host calls deactivate()
  CLAP_AUDIO_PORTS_RESCAN_ALL = 1 shl 0;

  // The ports name did change, the host can scan them right away.
  CLAP_AUDIO_PORTS_RESCAN_NAMES = 1 shl 1;

type
  Tclap_host_audio_ports = record
    // Rescan the full list of audio ports according to the flags.
    // [main-thread,!active]
    //void (*rescan)(const clap_host_t *host, uint32_t flags);
    rescan: procedure(host: Pclap_host; flags: uint32_t); cdecl;
  end;


//ext\note-ports.h

/// @page Note Ports
///
/// This extension provides a way for the plugin to describe its current note ports.
///
/// If the plugin does not implement this extension, it will have a single note input and output.
///
/// The plugin is only allowed to change its note ports configuration while it is deactivated.

const
  CLAP_EXT_NOTE_PORTS = AnsiString('clap.note-ports');

   // Uses clap_event_note and clap_event_note_expression.
   // Default if the port info are not provided or inspected.
  CLAP_NOTE_DIALECT_CLAP = 1 shl 0;

   // Uses clap_event_midi, no polyphonic expression
  CLAP_NOTE_DIALECT_MIDI = 1 shl 1;

   // Uses clap_event_midi, with polyphonic expression
  CLAP_NOTE_DIALECT_MIDI_MPE = 1 shl 2;

   // Uses clap_event_midi2
  CLAP_NOTE_DIALECT_MIDI2 = 1 shl 3;

type
  Tclap_note_port_info = record
    id: Tclap_id;                       // stable identifier
    supported_dialects: uint32_t; // bitfield, see clap_note_dialect
    preferred_dialect: uint32_t;  // one value of clap_note_dialect
    name: array[0..CLAP_NAME_SIZE - 1] of byte;        // displayable name, i18n?
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
/// The host sees the plugin as an atomic entity; and acts as a controler on top of its parameters.
/// The plugin is responsible to keep in sync its audio processor and its GUI.
///
/// The host can read at any time parameters value on the [main-thread] using
/// @ref clap_plugin_params.value().
///
/// There is two options to communicate parameter value change, and they are not concurrent.
/// - send automation points during clap_plugin.process()
/// - send automation points during clap_plugin_params.flush(), this one is used when the plugin is
///   not processing
///
/// When the plugin changes a parameter value, it must inform the host.
/// It will send @ref CLAP_EVENT_PARAM_VALUE event during process() or flush().
/// - set the flag CLAP_EVENT_PARAM_BEGIN_ADJUST to mark the begining of automation recording
/// - set the flag CLAP_EVENT_PARAM_END_ADJUST to mark the end of automation recording
/// - set the flag CLAP_EVENT_PARAM_SHOULD_RECORD if the event should be recorded
///
/// @note MIDI CCs are a tricky because you may not know when the parameter adjustment ends.
/// Also if the hosts records incoming MIDI CC and parameter change automation at the same time,
/// there will be a conflict at playback: MIDI CC vs Automation.
/// The parameter automation will always target the same parameter because the param_id is stable.
/// The MIDI CC may have a different mapping in the future and may result in a different playback.
///
/// When a MIDI CC changes a parameter's value, set @ref clap_event_param.should_record to false.
/// That way the host may record the MIDI CC automation, but not the parameter change and there
/// won't be conflict at playback.
///
/// Scenarios:
///
/// I. Loading a preset
/// - load the preset in a temporary state
/// - call @ref clap_host_params.changed() if anything changed
/// - call @ref clap_host_latency.changed() if latency changed
/// - invalidate any other info that may be cached by the host
/// - if the plugin is activated and the preset will introduce breaking change
///   (latency, audio ports, new parameters, ...) be sure to wait for the host
///   to deactivate the plugin to apply those changes.
///   If there are no breaking changes, the plugin can apply them them right away.
///   The plugin is resonsible to update both its audio processor and its gui.
///
/// II. Turning a knob on the DAW interface
/// - the host will send an automation event to the plugin via a process() or flush()
///
/// III. Turning a knob on the Plugin interface
/// - if the plugin is not processing, call clap_host_params->request_flush() or
///   clap_host->request_process().
/// - send an automation event and don't forget to set begin_adjust, end_adjust and should_record
///   attributes
/// - the plugin is responsible to send the parameter value to its audio processor
///
/// IV. Turning a knob via automation
/// - host sends an automation point during clap_plugin->process() or clap_plugin_params->flush().
/// - the plugin is responsible to update its GUI
///
/// V. Turning a knob via plugin's internal MIDI mapping
/// - the plugin sends a CLAP_EVENT_PARAM_SET output event, set should_record to false
/// - the plugin is responsible to update its GUI
///
/// VI. Adding or removing parameters
/// - if the plugin is activated call clap_host->restart()
/// - once the plugin isn't active:
///   - apply the new state
///   - call clap_host_params->rescan(CLAP_PARAM_RESCAN_ALL)
///   - if a parameter is created with an id that may have been used before,
///     call clap_host_params.clear(host, param_id, CLAP_PARAM_CLEAR_ALL)

const
  CLAP_EXT_PARAMS = AnsiString('clap.params');

  // Is this param stepped? (integer values only)
  // if so the double value is converted to integer using a cast (equivalent to trunc).
  CLAP_PARAM_IS_STEPPED = 1 shl 0;

  // Does this param supports per note automations?
  CLAP_PARAM_IS_PER_NOTE = 1 shl 1;

  // Does this param supports per channel automations?
  CLAP_PARAM_IS_PER_CHANNEL = 1 shl 2;

  // Does this param supports per port automations?
  CLAP_PARAM_IS_PER_PORT = 1 shl 3;

  // Useful for for periodic parameters like a phase
  CLAP_PARAM_IS_PERIODIC = 1 shl 4;

  // The parameter should not be shown to the user, because it is currently not used.
  // It is not necessary to process automation for this parameter.
  CLAP_PARAM_IS_HIDDEN = 1 shl 5;

  // This parameter is used to merge the plugin and host bypass button.
  // It implies that the parameter is stepped.
  // min: 0 -> bypass off
  // max: 1 -> bypass on
  CLAP_PARAM_IS_BYPASS = (1 shl 6) or CLAP_PARAM_IS_STEPPED;

  // The parameter can't be changed by the host.
  CLAP_PARAM_IS_READONLY = 1 shl 7;

  // Does the parameter support the modulation signal?
  CLAP_PARAM_IS_MODULATABLE = 1 shl 8;

  // Any change to this parameter will affect the plugin output and requires to be done via
  // process() if the plugin is active.
  //
  // A simple example would be a DC Offset, changing it will change the output signal and must be
  // processed.
  CLAP_PARAM_REQUIRES_PROCESS = 1 shl 9;

type
  Tclap_param_info_flags = uint32_t;

/////* This describes a parameter */
  Tclap_param_info = record
    // stable parameter identifier, it must never change.
    id: Tclap_id;

    flags: Tclap_param_info_flags;

    // This value is optional and set by the plugin.
    // Its purpose is to provide a fast access to the plugin parameter:
    //
    //    Parameter *p = findParameter(param_id);
    //    param_info->cookie = p;
    //
    //    /* and later on */
    //    Parameter *p = (Parameter *)cookie;
    //
    // It is invalidated on clap_host_params->rescan(CLAP_PARAM_RESCAN_ALL) and when the plugin is
    // destroyed.
    cookie: pointer;

    name: array[0..CLAP_NAME_SIZE - 1] of byte;     // the display name
    module: array[0..CLAP_MODULE_SIZE - 1] of byte; // the module containing the param, eg:
                                             // "oscillators/wt1"; '/' will be used as a
                                             // separator to show a tree like structure.

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
    // This method must not be used if the plugin is processing.
    //
    // [active && !processing : audio-thread]
    // [!active : main-thread]
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
   //   - is_per_channel (flag)
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

    // Clears references to a parameter
    // [main-thread]
    //void (*clear)(const clap_host_t *host, clap_id param_id, clap_param_clear_flags flags);
    clear: procedure(host: Pclap_host; param_id: Tclap_id; flags: Tclap_param_clear_flags); cdecl;

    // Request the host to call clap_plugin_params->fush().
    // This is useful if the plugin has parameters value changes to report to the host but the plugin
    // is not processing.
    //
    // eg. the plugin has a USB socket to some hardware controllers and receives a parameter change
    // while it is not processing.
    //
    // This must not be called on the [audio-thread].
    //
    // [thread-safe]
    //void (*request_flush)(const clap_host_t *host);
    request_flush: procedure(host: Pclap_host); cdecl;
  end;
  Pclap_host_params = ^Tclap_host_params;


//ext\event-filter.h

const
  CLAP_EXT_EVENT_FILTER = AnsiString('clap.event-filter');

// This extension lets the host know which event types the plugin is interested
// in.
// The host will cache the set of accepted events before activating the plugin.
// The set of accepted events can't change while the plugin is active.
//
// If this extension is not provided by the plugin, then all events are accepted.
//
// If CLAP_EVENT_TRANSPORT is not accepted, then clap_process.transport may be null.
type
  Tclap_plugin_event_filter = record
    // Returns true if the plugin is interested in the given event type.
    // [main-thread]
    //bool (*accepts)(const clap_plugin_t *plugin, uint16_t space_id, uint16_t event_type);
    accepts: function(plugin: Pclap_plugin; space_id: uint16_t; event_type: Tclap_event_type): boolean; cdecl;
  end;
  Pclap_plugin_event_filter = ^Tclap_plugin_event_filter;

  Tclap_host_event_filter = record
    // Informs the host that the set of accepted event type changed.
    // This requires the plugin to be deactivated.
    // [main-thread]
    //void (*changed)(const clap_host_t *host);
    changed: procedure(host: Pclap_host); cdecl;
  end;


//ext\note-name.h

const
  CLAP_EXT_NOTE_NAME = AnsiString('clap.note-name');

type
  Tclap_note_name = record
    name: array[0..CLAP_NAME_SIZE - 1] of byte;
    port: int32_t;
    key: int32_t;
    channel: int32_t; // -1 for every channels
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
    // Informs the host that the note names has changed.
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

// This interface is useful to do runtime checks and make
// sure that the functions are called on the correct threads.
// It is highly recommended to implement this extension
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


//converters\vst2-converter.h

// This interface provide all the tool to convert a vst2 plugin instance into a clap plugin instance
type
  Pclap_vst2_converter = ^Tclap_vst2_converter;
  Tclap_vst2_converter = record
    vst2_plugin_id: uint32_t;
    vst2_plugin_name: PAnsiChar;
    clap_plugin_id: PAnsiChar;

    // [main-thread]
    //bool (*convert_state)(const struct clap_vst2_converter *converter,
    //                      const clap_istream_t             *vst2,
    //                      const clap_ostream_t             *clap);
    convert_state: function(converter:Pclap_vst2_converter; vst2: Pclap_istream; clap: Pclap_ostream): boolean; cdecl;

    // converts the vst2 param id and normalized value to clap param id and
    // plain value.
    // [thread-safe]
    //bool (*convert_normalized_value)(const struct clap_vst2_converter *converter,
    //                                 uint32_t                          vst2_param_id,
    //                                 double                            vst2_normalized_value,
    //                                 clap_id                          *clap_param_id,
    //                                 double                           *clap_plain_value);
    convert_normalized_value: function(converter: Pclap_vst2_converter; vst2_param_id: uint32_t; vst2_normalized_value: double;
                                       var clap_param_id: Tclap_id; var clap_plain_value: double): boolean; cdecl;

    // converts the vst2 param id and plain value to clap param id and
    // plain value.
    // [thread-safe]
    //bool (*convert_plain_value)(const struct clap_vst2_converter *converter,
    //                            uint32_t                          vst2_param_id,
    //                            double                            vst2_plain_value,
    //                            clap_id                          *clap_param_id,
    //                            double                           *clap_plain_value);
    convert_plain_value: function(converter: Pclap_vst2_converter; vst2_param_id: uint32_t; vst2_plain_value: double;
                                  var clap_param_id: Tclap_id; var clap_plain_value: double): boolean; cdecl;
  end;

// Factory identifier
const
  CLAP_VST2_CONVERTER_FACTORY_ID = AnsiString('clap.vst2-converter-factory');

// List all the converters available in the current DSO.
type
  Pclap_vst2_converter_factory = ^Tclap_vst2_converter_factory;
  Tclap_vst2_converter_factory = record
    // Get the number of converters
    //uint32_t (*count)(const struct clap_vst2_converter_factory *factory);
    count: function(factory: Pclap_vst2_converter_factory): uint32_t; cdecl;

    // Get the converter at the given index
    //const clap_vst2_converter_t *(*get)(const struct clap_vst2_converter_factory *factory,
    //                                    uint32_t                                  index);
    get: function(factory: Pclap_vst2_converter_factory; index: uint32_t): Pclap_vst2_converter; cdecl;
  end;


//converters\vst3-converter.h

// This interface provide all the tool to convert a vst3 plugin instance into a clap plugin instance
type
  Pclap_vst3_converter = ^Tclap_vst3_converter;
  Tclap_vst3_converter = record
   // The VST FUID can be constructed by:
   // Steinberg::FUID::fromTUID(conv->vst3_plugin_tuid);
    vst3_plugin_tuid: TGUID;
    clap_plugin_id: PAnsiChar;

    // [main-thread]
    //bool (*convert_state)(const struct clap_vst3_converter *converter,
    //                     const clap_istream_t             *vst3_processor,
    //                     const clap_istream_t             *vst3_editor,
    //                     const clap_ostream_t             *clap);
    convert_state: function(converter: Pclap_vst3_converter; vst3_processor, vst3_editor: Pclap_istream; clap: Pclap_ostream): boolean; cdecl;

    // converts the vst3 param id and normalized value to clap param id and
    // plain value.
    // [thread-safe]
    //bool (*convert_normalized_value)(const struct clap_vst3_converter *converter,
    //                                uint32_t                          vst3_param_id,
    //                                double                            vst3_normalized_value,
    //                                clap_id                          *clap_param_id,
    //                                double                           *clap_plain_value);
    convert_normalized_value: function(converter: Pclap_vst3_converter; vst3_param_id: uint32_t; vst3_normalized_value: double;
                                       var clap_param_id: Tclap_id; var clap_plain_value: double): boolean; cdecl;

    // converts the vst3 param id and plain value to clap param id and
    // plain value.
    // [thread-safe]
    //bool (*convert_plain_value)(const struct clap_vst3_converter *converter,
    //                           uint32_t                          vst3_param_id,
    //                           double                            vst3_plain_value,
    //                           clap_id                          *clap_param_id,
    //                           double                           *clap_plain_value);
    convert_plain_value: function(converter: Pclap_vst3_converter; vst3_param_id: uint32_t; vst3_plain_value: double;
                                  var clap_param_id: Tclap_id; var clap_plain_value: double): boolean; cdecl;
  end;

// Factory identifier
const
  CLAP_VST3_CONVERTER_FACTORY_ID = AnsiString('clap.vst3-converter-factory');

// List all the converters available in the current DSO.
type
  Pclap_vst3_converter_factory = ^Tclap_vst3_converter_factory;
  Tclap_vst3_converter_factory = record
    // Get the number of converters
    //uint32_t (*count)(const struct clap_vst3_converter_factory *factory);
    count: function(factory: Pclap_vst3_converter_factory): uint32_t; cdecl;

    // Get the converter at the given index
    //const clap_vst3_converter_t *(*get)(const struct clap_vst3_converter_factory *factory,
    //                                    uint32_t                                  index);
    get: function(factory: Pclap_vst3_converter_factory; index: uint32_t): Pclap_vst3_converter; cdecl;
  end;

implementation

function clap_version_is_compatible(const v: Tclap_version): boolean;
begin
  result := (v.major = CLAP_VERSION_MAJOR) and (v.minor = CLAP_VERSION_MINOR);
end;

end.
