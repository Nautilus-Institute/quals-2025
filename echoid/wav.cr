module EchoID
    # Parses the fmt header and leaves io pointing at data header
    struct WavHeader
        RIFF_CHUNK_ID = 0x46464952_u32  # "RIFF" in ASCII
        WAVE_FORMAT_ID = 0x45564157_u32 # "WAVE" in ASCII
        FMT_CHUNK_ID = 0x20746d66_u32   # "fmt " in ASCII
        DATA_CHUNK_ID = 0x61746164_u32  # "data" in ASCII
        WAVE_FORMAT_PCM = 0x0001_u16        # Format ID for PCM from WAV spec
        WAVE_FORMAT_IEEE_FLOAT = 0x0003_u16 # Format ID for IEEE Float from WAV spec
        WAVE_FORMAT_EXTENSIBLE = 0xFFFE_u16 # Format ID for Extensible from WAV spec
        WAVE_PCM_GUID = Bytes[
            0x01_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x10_u8, 0x00_u8,
            0x80_u8, 0x00_u8, 0x00_u8, 0xAA_u8, 0x00_u8, 0x38_u8, 0x9B_u8, 0x71_u8
        ] # The GUID for PCM in an Extensible WAV (first 2 bytes match WAVE_FORMAT_PCM)

        property format : UInt16
        property channels : UInt16
        property sample_rate : UInt32
        property data_rate : UInt32
        property block_align : UInt16
        property bits_per_sample : UInt16
        property data_size : UInt32

        def initialize
            @format = 0_u16
            @channels = 0_u16
            @sample_rate = 0_u32
            @data_rate = 0_u32
            @block_align = 0_u16
            @bits_per_sample = 0_u16
            @data_size = 0_u32
        end

        # Parses the WAV header
        def load(io : IO)
            # Read RIFF header
            riff = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
            chunks = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
            format = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)

            # Make sure it's a valid WAV file
            unless riff == RIFF_CHUNK_ID
                raise "Not a valid WAV file: RIFF header not found"
            end
            unless format == WAVE_FORMAT_ID
                raise "Not a valid WAV file: WAVE format not found"
            end

            # Record the start of the data so we can come back to it
            data_start = io.tell

            # Find and read the format chunk
            fmt_found = false
            loop do
                chunk_id = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
                chunk_size = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)

                if chunk_id == FMT_CHUNK_ID
                    # Read the fmt chunk
                    @format = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
                    @channels = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
                    @sample_rate = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
                    @data_rate = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
                    @block_align = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
                    @bits_per_sample = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
                    if @format == WAVE_FORMAT_EXTENSIBLE
                        extension_size = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
                        if extension_size == 22
                            io.skip(6)
                            subformat_guid = Bytes.new(16)
                            io.read_fully(subformat_guid)
                            @format = WAVE_FORMAT_PCM if subformat_guid == WAVE_PCM_GUID
                        end
                    end
                    fmt_found = true
                    break
                else
                    # Skip this chunk
                    io.skip(chunk_size)
                end
            end
            if !fmt_found
                raise "Not a valid WAV file: fmt chunk not found"
            end

            # Go back to the start of all data
            io.seek(data_start)

            # Find the first data chunk
            data_found = false
            loop do
                chunk_id = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
                chunk_size = io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)

                if chunk_id == DATA_CHUNK_ID
                    # Reading the data chunk is not our job
                    @data_size = chunk_size
                    data_found = true
                    break
                else
                    # Skip this chunk
                    io.skip(chunk_size)
                end
            end
            if !data_found
                raise "Not a valid WAV file: data chunk not found"
            end
        end
    end

    # Parses files in WAV format and extracts samples
    class WavFile
        property header : WavHeader
        property data : Array(Float64)

        def initialize(path : String)
            @header = WavHeader.new()
            @data = [] of Float64

            {% if flag?(:debug) %}
                puts "Loading audio file: #{path}"
            {% end %}

            File.open(path, "rb") do |file|
                @header.load(file)

                {% if flag?(:debug) %}
                    puts "WAV file details:"
                    puts "  Sample rate: #{@header.sample_rate} Hz"
                    puts "  Channels: #{@header.channels}"
                    puts "  Bits per sample: #{@header.bits_per_sample}"
                    puts "  Data size: #{@header.data_size} bytes"
                {% end %}

                @data = load(file)
            end
        end

        # Parses WAV file and extracts audio samples
        private def load(io : IO) : Array(Float64)
            # Check if format is supported
            unless @header.format == WavHeader::WAVE_FORMAT_PCM || @header.format == WavHeader::WAVE_FORMAT_IEEE_FLOAT
                raise "Unsupported WAV format: #{@header.format}\nOnly PCM and IEEE_FLOAT (uncompressed) formats are supported"
            end

            # Extract audio samples
            samples = extract_samples(io)

            # If stereo, convert to mono
            if @header.channels > 1
                samples = convert_to_mono(samples)
            end

            return samples
        end

        # Extract samples from WAV data
        private def extract_samples(io : IO) : Array(Float64)
            samples = [] of Float64
            bytes_per_sample = @header.bits_per_sample // 8
            num_samples = @header.data_size // bytes_per_sample

            num_samples.times do |i|
                # Read sample based on bit depth
                sample_value = 0.0

                case @header.bits_per_sample
                when 8
                    # 8-bit samples are unsigned
                    byte_value = io.read_byte.not_nil!
                    sample_value = (byte_value.to_f64 - 128.0) / 128.0 # 2^7
                when 16
                    # 16-bit samples are signed
                    short_value = io.read_bytes(Int16, IO::ByteFormat::LittleEndian)
                    sample_value = short_value.to_f64 / 32768.0 # 2^15
                when 24
                    # 24-bit samples are signed (read as 3 bytes and convert to int)
                    byte1 = io.read_byte.not_nil!
                    byte2 = io.read_byte.not_nil!
                    byte3 = io.read_byte.not_nil!
                    int_value = (byte3.to_i32 << 16) | (byte2.to_i32 << 8) | byte1.to_i32

                    # Sign extension for negative values
                    if (int_value & 0x800000) != 0
                        int_value |= (~0) << 24
                    end

                    sample_value = int_value.to_f64 / 8388608.0 # 2^23
                when 32
                    case @header.format
                    when WavHeader::WAVE_FORMAT_PCM
                        # 32-bit integer samples
                        int_value = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
                        sample_value = int_value.to_f64 / 2147483648.0 # 2^31
                    when WavHeader::WAVE_FORMAT_IEEE_FLOAT
                        # 32-bit float samples
                        float_value = io.read_bytes(Float32, IO::ByteFormat::LittleEndian)
                        sample_value = float_value.to_f64
                    else
                        raise "Unsupported 32-bit format: #{@header.format}"
                    end
                  when 64
                    if @header.format == WavHeader::WAVE_FORMAT_IEEE_FLOAT
                        # 64-bit float samples
                        sample_value = io.read_bytes(Float64, IO::ByteFormat::LittleEndian)
                    else
                        raise "Unsupported 64-bit format: #{@header.format}"
                    end
                else
                    raise "Unsupported bit depth: #{@header.bits_per_sample}"
                end

                samples << sample_value
            end

            return samples
        end

        # Convert multi-channel audio to mono
        private def convert_to_mono(samples : Array(Float64)) : Array(Float64)
            {% if flag?(:debug) %}
                puts "Converting #{@header.channels} channels to mono"
            {% end %}

            mono_samples = [] of Float64
            num_samples = samples.size // @header.channels

            num_samples.times do |i|
                sample_sum = 0.0

                # Average all channels for this sample
                @header.channels.times do |ch|
                    sample_index = i * header.channels + ch
                    sample_sum += samples[sample_index]
                end

                mono_samples << sample_sum / @header.channels
            end

            @header.channels = 1

            return mono_samples
        end
    end
end
