#!/usr/bin/env crystal

require "option_parser"
require "./audioprocessor"
require "./database"

module EchoID
    DATABASE_LOCATION = "./fingerprints.db"

    # Main application
    class CLI
        MAX_FILE_SIZE = 4 * 1024 * 1024 # Chose 4MB based on length of PCM 44.1KHz 32-bit audio
        MAX_READ_TIMEOUT = 10.seconds
        HIGH_CONFIDENCE_SCORE = 50000   # Chosen arbitrarily via random testing

        property mode : String?
        property input_file : String?
        property artist : String?
        property title : String?
        property id : String?
        property parser : OptionParser

        def initialize
            @mode = nil
            @input_file = nil
            @artist = nil
            @title = nil
            @id = nil
            @parser = OptionParser.new
        end

        # Parses command line arguments
        def parse_arguments
            OptionParser.parse do |parser|
                parser.banner = "Usage: audio_fingerprinter <command> [options]"

                parser.on("add", "Add a song to the database") do
                    @mode = "add"
                end

                parser.on("find", "Find a matching song from a sample provided on stdin") do
                    @mode = "find"
                end

                parser.on("list", "List all of the songs in the database") do
                    @mode = "list"
                end

                parser.on("update", "Update the details of a song in the database") do
                    @mode = "update"
                end

                parser.on("clear", "Clear all the songs from the database") do
                    @mode = "clear"
                end

                parser.on("help", "Show this help") do
                    @mode = "help"
                end

                parser.on("version", "Show version") do
                    @mode = "version"
                end

                parser.on("-i FILE", "--input=FILE", "Input audio file") do |file|
                    @input_file = file
                end

                parser.on("-a NAME", "--artist=NAME", "Artist name") do |name|
                    @artist = name
                end

                parser.on("-t TITLE", "--title=TITLE", "Song title") do |title|
                    @title = title
                end

                parser.on("-s ID", "--song=ID", "Song identifier") do |id|
                    @id = id
                end

                parser.invalid_option do |flag|
                    STDERR.puts "ERROR: #{flag} is not a valid option."
                    STDERR.puts parser
                    exit(1)
                end
            end

            unless @mode
                STDERR.puts "ERROR: You must specify a command (add, find, help, or version)"
                exit(1)
            end
        end

        # Execute the program based on the mode
        def run
            case @mode
            when "add"
                run_add_mode
            when "find"
                run_find_mode
            when "list"
                run_list_mode
            when "update"
                run_update_mode
            when "clear"
                run_clear_mode
            when "help"
                show_help
            when "version"
                show_version
            end
        end

        # Add mode implementation
        def run_add_mode
            {% if flag?(:debug) %}
                puts "Running in add mode"
            {% end %}

            if !@input_file
                STDERR.puts "ERROR: -i flag is required for add mode"
                exit(1)
            end
            if !@artist
                STDERR.puts "ERROR: -a flag is required for add mode"
                exit(1)
            end
            if !@title
                STDERR.puts "ERROR: -t flag is required for add mode"
                exit(1)
            end
            path = @input_file.not_nil!
            artist = @artist.not_nil!
            title = @title.not_nil!

            {% if flag?(:debug) %}
                puts "Input file: #{path}"
                puts "Artist: #{artist}"
                puts "Title: #{title}"
            {% end %}

            # Open database
            begin
                db = Database.new(DATABASE_LOCATION)
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while opening the database:"
                STDERR.puts ex.message
                exit(1)
            end

            # Generate fingerprints
            fingerprints = generate_fingerprints(path)
            if fingerprints.empty?
                STDERR.puts "ERROR: No fingerprints were generated!"
            end

            # Add fingerprints to database
            begin
                db.insert_song(artist, title, fingerprints)
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while adding the song to the database:"
                STDERR.puts ex.message
                exit(1)
            end

            puts "Successfully added '#{title}' by #{artist} to the database"
        end

        private def generate_fingerprints(path : String) : Hash(UInt64, Array(Int32))
            if File.extname(path) != ".wav"
                STDERR.puts "ERROR: Unsupported file format: #{File.extname(path)}"
                exit(1)
            end

            # Parse input file
            file = WavFile.new(path)

            # Process audio data
            processor = AudioProcessor.new()
            audio = processor.downsample(file.data, file.header.sample_rate)
            spectrogram = processor.create_spectrogram(audio)
            peaks = processor.extract_peaks(spectrogram)

            # Create fingerprints
            fingerprints = processor.generate_fingerprints(peaks)

            # Transform them into a format the database understands
            db_fingerprints = Hash(UInt64, Array(Int32)).new { |h, k| h[k] = [] of Int32 }

            fingerprints.each do |fp|
                hash = fp.hash
                offset = fp.anchor_time.to_i32
                db_fingerprints[hash] << offset
            end

            return db_fingerprints
        rescue ex : Exception
            STDERR.puts "ERROR: An exception occurred while processing the audio file:"
            STDERR.puts ex.message
            exit(1)
        end

        # Find mode implementation
        def run_find_mode
            {% if flag?(:debug) %}
                puts "Running in find mode"
            {% end %}

            # Read from stdin
            path = get_input()

            # Open database
            begin
                db = Database.new(DATABASE_LOCATION)
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while opening the database:"
                STDERR.puts ex.message
                exit(1)
            end

            # Generate fingerprints
            fingerprints = generate_fingerprints(path)
            if fingerprints.empty?
                STDERR.puts "ERROR: No fingerprints!"
            end

            # Look for match
            #matches = db.find_matches_simple(fingerprints)
            matches = db.find_matches(fingerprints)

            # if matches.empty?
            #     puts "No matching songs found"
            # else
            #     high_confidence_matches = matches.select { |match| match.score > HIGH_CONFIDENCE_SCORE }
            #     if high_confidence_matches.empty?
            #         puts "No high-confidence matches found"
            #         puts "Found #{matches.size} potential low-confidence matches"
            #     else
            #         puts "Found #{high_confidence_matches.size} high-confidence matches"
            #         high_confidence_matches.each_with_index do |match, i|
            #             puts "Match #{i+1}: #{match.to_s}"
            #         end
            #     end
            # end
            matches.each_with_index do |match, i|
                puts "Match #{i+1}: #{match.to_s}" # TODO
            end
        end

        private def get_input : String
            # Added a banner here so teams can see that the service is working
            puts "Send us your song to be identified"

            # # Read the expected size of the audio we will receive
            # size_buffer = Bytes.new(4)
            # bytes_read = STDIN.read(size_buffer)
            # if bytes_read != 4
            #     STDERR.puts "ERROR: Failed to read size information"
            #     exit(1)
            # end

            # # Make sure the expected size is reasonable
            # expected_size = IO::ByteFormat::LittleEndian.decode(Int32, size_buffer)
            # if expected_size <= 0 || expected_size > MAX_FILE_SIZE
            #     STDERR.puts "ERROR: Invalid input size: #{expected_size}"
            #     exit(1)
            # end
            expected_size = 100000000 # TODO

            # Read the data from stdin
            total_bytes_read = 0
            input_data = IO::Memory.new
            buffer = Bytes.new(8192) # 8KB buffer
            start_time = Time.monotonic
            STDIN.read_timeout = 1.second # Set the read timeout
            while !STDIN.closed? && total_bytes_read < expected_size
                remaining = expected_size - total_bytes_read
                read_size = [remaining, buffer.size].min

                # Read data with timeout
                begin
                    bytes_read = STDIN.read(buffer[0, read_size])
                    if bytes_read == 0
                        # End of input
                        break
                    else
                        input_data.write(buffer[0, bytes_read])
                        total_bytes_read += bytes_read
                    end
                rescue IO::TimeoutError
                    # Fall through
                end

                # Check if we've exceeded the overall timeout
                if Time.monotonic - start_time > MAX_READ_TIMEOUT
                    STDERR.puts "ERROR: Timeout while reading input"
                    exit(1)
                end
            end

            if input_data.size == 0
                STDERR.puts "ERROR: No input received"
                exit(1)
            end

            puts "Received #{total_bytes_read} bytes of input"
            if total_bytes_read < expected_size
                STDERR.puts "WARNING: Received fewer bytes than expected (#{total_bytes_read} < #{expected_size})"
            end

            # Save to temporary file
            temp_file = File.tempfile("echoid", ".wav")
            temp_file.write(input_data.to_slice)
            temp_file.close

            {% if flag?(:debug) %}
                puts "Temporary audio file saved to #{temp_file.path}"
            {% end %}

            return temp_file.path
        end

        def run_list_mode
            {% if flag?(:debug) %}
                puts "Running in list mode"
            {% end %}

            # Open database and list songs
            begin
                db = Database.new(DATABASE_LOCATION)
                songs = db.list_songs()
                songs.each do |song|
                    puts song.to_s
                end
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while opening the database:"
                STDERR.puts ex.message
                exit(1)
            end
        end

        def run_update_mode
            {% if flag?(:debug) %}
                puts "Running in update mode"
            {% end %}

            if !@id
                STDERR.puts "ERROR: -n flag is required for update mode"
                exit(1)
            end
            if !@artist && !@title
                STDERR.puts "ERROR: Either -a or -t flag is required for update mode"
                exit(1)
            end
            id = @id.not_nil!
            artist = @artist || ""
            title = @title || ""

            # Open database
            begin
                db = Database.new(DATABASE_LOCATION)
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while opening the database:"
                STDERR.puts ex.message
                exit(1)
            end

            # Update song in database
            begin
                db.update_song(id, artist, title)
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while updating the song:"
                STDERR.puts ex.message
                exit(1)
            end
        end

        def run_clear_mode
            {% if flag?(:debug) %}
                puts "Running in clear mode"
            {% end %}

            # Open and clear database
            begin
                db = Database.new(DATABASE_LOCATION)
                db.clear_fingerprints()
            rescue ex : Exception
                STDERR.puts "ERROR: An exception occurred while opening the database:"
                STDERR.puts ex.message
                exit(1)
            end
        end

        def show_help
            puts @parser
        end

        def show_version
            puts "EchoID v#{{{ `shards version #{__DIR__}`.chomp.stringify }}}"
        end
    end
end

# Application entry point
cli = EchoID::CLI.new
cli.parse_arguments()
cli.run()
