require "sqlite3"
require "uuid"

module EchoID
    # Data structure for song information
    struct SongInfo
        property id : String
        property artist : String
        property title : String
        property added_at : String
        property fingerprint_count : Int64

        def initialize(@id, @artist, @title, @added_at, @fingerprint_count)
        end

        def to_s
            "#{id}: #{@artist} - #{@title} (#{@fingerprint_count} fingerprints)"
        end
    end

    # Data structure for initial candidate match
    struct Candidate
        property song_id : String
        property offset : UInt32

        def initialize(@song_id, @offset)
        end
    end

    # Data structure for match results
    struct MatchResult
        property song_id : String
        property artist : String
        property title : String
        property offset : Int32
        property score : Int32

        def initialize(@song_id, @artist, @title, @offset, @score)
        end

        def to_s
            "'#{@title}' by #{@artist} (score: #{@score})"
        end
    end

    # Database for storing and retrieving fingerprints
    class Database
        DEFAULT_MATCH_THRESHOLD = 10_u32
        DEFAULT_TARGET_ZONE_SIZE = 3_u32
        DEFAULT_TIMING_TOLERANCE = 100_u32

        property db : DB::Database
        property db_location : String

        def initialize(@db_location)
            @db = init_database
        end

        # Initialize the database and create necessary tables if they don't exist
        def init_database
            {% if flag?(:debug) %}
                puts "Setting up fingerprint database at #{@db_location}"
            {% end %}

            DB.open "sqlite3://#{@db_location}" do |db|
                # Create songs table
                db.exec "CREATE TABLE IF NOT EXISTS songs (
                    id TEXT PRIMARY KEY,
                    artist TEXT NOT NULL,
                    title TEXT NOT NULL,
                    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )"

                # Create fingerprints table
                db.exec "CREATE TABLE IF NOT EXISTS fingerprints (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    song TEXT NOT NULL,
                    hash INTEGER NOT NULL,
                    offset INTEGER NOT NULL,
                    FOREIGN KEY (song) REFERENCES songs(id),
                    UNIQUE (song, hash, offset)
                )"

                # Create index for faster lookups
                db.exec "CREATE INDEX IF NOT EXISTS idx_fingerprints_hash ON fingerprints (hash)"

                return db
            end
        end

        # Add a song to the database
        def insert_song(artist : String, title : String, fingerprints : Hash(UInt64, Array(Int32))) : String
            {% if flag?(:debug) %}
                puts "Adding song: '#{title}' by #{artist}"
                puts "Number of fingerprints: #{fingerprints.size}"
            {% end %}

            song_id = ""
            @db.transaction do |tx|
                # Insert or get song
                song_id = get_or_create_song(tx.connection, artist, title)

                # Insert fingerprints
                insert_fingerprints(tx.connection, song_id, fingerprints)
            end

            {% if flag?(:debug) %}
                puts "Inserted fingerprints for song ID #{song_id}"
            {% end %}

            return song_id
        end

        # Insert fingerprints for a song
        private def insert_fingerprints(db : DB::Connection, song_id : String, fingerprints : Hash(UInt64, Array(Int32)))
            # Prepare statement for better performance
            statement = db.prepared "INSERT INTO fingerprints (song, hash, offset) VALUES (?, ?, ?) ON CONFLICT (song, hash, offset) DO NOTHING"

            # Insert each fingerprint
            count = 0
            fingerprints.each do |hash, offsets|
                offsets.each do |offset|
                    statement.exec song_id, hash.to_i64!, offset
                    count += 1

                    # Log progress for large datasets
                    {% if flag?(:debug) %}
                        if count % 1000 == 0
                            puts "Inserted #{count} fingerprints..."
                        end
                    {% end %}
                end
            end

            statement.close
        end

        # Get an existing song given its identifier
        def get_song(id : String) : SongInfo?
            result = @db.query_one? "SELECT id, artist, title, added_at FROM songs WHERE id = ?", id, as: {String, String, String, String}

            if result
                id, artist, title, added_at = result
                fingerprint_count = @db.scalar("SELECT COUNT(*) FROM fingerprints WHERE song = ?", id).as(Int64)

                return SongInfo.new(
                    id: id,
                    artist: artist,
                    title: title,
                    added_at: added_at,
                    fingerprint_count: fingerprint_count
                )
            else
                return nil
            end
        end

        # Get an existing song or create a new one if it doesn't exist
        private def get_or_create_song(db : DB::Connection, artist : String, title : String) : String
            # Check if song already exists
            result = db.query_one? "SELECT id FROM songs WHERE artist = ? AND title = ?", artist, title, as: {String}

            if result
                {% if flag?(:debug) %}
                    puts "Song already exists in database with ID #{result}"
                {% end %}
                return result
            end

            # Insert new song
            song_id = UUID.random.to_s
            db.exec "INSERT INTO songs (id, artist, title) VALUES (?, ?, ?)", song_id, artist, title

            {% if flag?(:debug) %}
                puts "Created new song entry with ID #{song_id}"
            {% end %}

            return song_id
        end

        # List all songs in the database
        def list_songs : Array(SongInfo)
            {% if flag?(:debug) %}
                puts "Listing all songs from the database"
            {% end %}

            songs = [] of SongInfo

            @db.query "SELECT id, artist, title, added_at FROM songs ORDER BY added_at DESC" do |rs|
                rs.each do
                    id = rs.read(String)
                    artist = rs.read(String)
                    title = rs.read(String)
                    added_at = rs.read(String)

                    # Get fingerprint count for this song
                    fingerprint_count = db.scalar "SELECT COUNT(*) FROM fingerprints WHERE song = ?", id

                    songs << SongInfo.new(
                        id: id,
                        artist: artist,
                        title: title,
                        added_at: added_at,
                        fingerprint_count: fingerprint_count.as(Int64)
                    )
                end
            end

            return songs
        end

        # Update song details in the database
        def update_song(id : String, artist : String, title : String)
            {% if flag?(:debug) %}
                puts "Updating details of song #{id} in the database"
            {% end %}

            @db.transaction do |tx|
                if artist != "" && title != ""
                    tx.connection.exec "UPDATE songs SET artist =?, title =? WHERE id =?", artist, title, id
                elsif artist != ""
                    tx.connection.exec "UPDATE songs SET artist =? WHERE id =?", artist, id
                elsif title != ""
                    tx.connection.exec "UPDATE songs SET title =? WHERE id =?", title, id
                else
                    raise ArgumentError.new("Either artist or title must be provided for updating")
                end
            end
        end

        # Clear the database
        def clear_fingerprints
            {% if flag?(:debug) %}
                puts "Clearing the fingerprint database"
            {% end %}

            @db.exec "DELETE FROM fingerprints"
            @db.exec "DELETE FROM songs"
            @db.exec "VACUUM" # Reclaim freed space

            {% if flag?(:debug) %}
                puts "Fingerprint database has been cleared"
            {% end %}
        end

        # Simple solution for finding matches for a set of fingerprints
        def find_matches_simple(fingerprints : Hash(UInt64, Array(Int32)), threshold : UInt32 = DEFAULT_MATCH_THRESHOLD) : Array(MatchResult)
            {% if flag?(:debug) %}
                puts "Searching for matches among #{fingerprints.size} fingerprints"
            {% end %}

            # Get time offset matches for each fingerprint
            song_offsets = Hash(UInt64, Hash(Int32, Int32)).new
            fingerprints.each do |hash, offsets|
                # Look up matching fingerprints in the database
                @db.query "SELECT song, offset FROM fingerprints WHERE hash = ?", hash do |rs|
                    rs.each do
                        song_id = rs.read(String)
                        db_offset = rs.read(Int32)

                        # Create entry for this song if it doesn't exist
                        song_offsets[song_id] ||= Hash(Int32, Int32).new(0)

                        # For each query offset of this hash
                        offsets.each do |offset|
                            # Calculate time delta between the query and the stored song
                            delta = db_offset - offset

                            # Increment count for this time delta
                            song_offsets[song_id][delta] ||= 0
                            song_offsets[song_id][delta] += 1
                        end
                    end
                end
            end

            # Process matches
            matches = [] of MatchResult
            song_offsets.each do |song_id, deltas|
                # Find most common delta and its count
                max_count = 0
                best_delta = 0

                deltas.each do |delta, count|
                    if count > max_count
                        max_count = count
                        best_delta = delta
                    end
                end

                # Skip if not enough matches
                if max_count >= threshold
                    # Get song details
                    song = @db.query_one "SELECT artist, title FROM songs WHERE id = ?", song_id, as: {String, String}

                    # Create match result
                    match = MatchResult.new(
                        song_id: song_id,
                        artist: song[0],
                        title: song[1],
                        offset: best_delta,
                        score: max_count
                    )

                    matches << match
                end
            end

            # Sort matches by confidence (highest first)
            matches.sort_by! { |m| -m.score }

            return matches
        end

        # More complex solution for finding matches for a set of fingerprints
        def find_matches(fingerprints : Hash(UInt64, Array(Int32))) : Array(MatchResult)
            {% if flag?(:debug) %}
                puts "Starting with #{fingerprints.size} fingerprints"
            {% end %}

            # Only consider first occurrence of each hash for speed
            fingerprint_map = Hash(UInt64, UInt32).new
            fingerprints.each do |hash, offsets|
                fingerprint_map[hash] = offsets.first.to_u32
            end

            {% if flag?(:debug) %}
                puts "Searching for matches among #{fingerprint_map.size} unique fingerprints"
            {% end %}

            # Turn candidates into matches
            matches, timestamps, target_zones = process_candidates(fingerprint_map)
            filtered_matches = filter_matches(matches, target_zones)
            scores = analyze_time_coherence(filtered_matches)

            # Prepare our results for the user
            results = [] of MatchResult
            scores.each do |song_id, points|
                song = get_song(song_id)
                next unless song

                match = MatchResult.new(
                    song_id: song_id,
                    artist: song.artist,
                    title: song.title,
                    offset: timestamps[song_id].to_i32,
                    score: points.to_i32
                )
                results << match
            end

            return results.sort_by! { |m| -m.score }
        end

        # Turns candidates into matches
        private def process_candidates(fingerprint_map : Hash(UInt64, UInt32)) : Tuple(Hash(String, Array(Tuple(UInt32, UInt32))), Hash(String, UInt32), Hash(String, Hash(UInt32, Int32)))
            matches = Hash(String, Array(Tuple(UInt32, UInt32))).new    # Matching hashes for each song
            timestamps = Hash(String, UInt32).new                       # Timestamp of earliest match per song
            target_zones = Hash(String, Hash(UInt32, Int32)).new        # Frequency of matches per zone per song

            get_candidates(fingerprint_map.keys).each do |hash, candidates|
                candidates.each do |c|
                    matches[c.song_id] ||= [] of Tuple(UInt32, UInt32)
                    if fingerprint_map.has_key?(hash)
                        # We have a potential match for this song
                        matches[c.song_id] << {fingerprint_map[hash], c.offset}

                        # If this offset is the earliest we've found so far, record it
                        if !timestamps.has_key?(c.song_id) || c.offset < timestamps[c.song_id]
                            timestamps[c.song_id] = c.offset
                        end

                        # Increment the count for this offset in the target zone
                        target_zones[c.song_id] ||= Hash(UInt32, Int32).new(0)
                        target_zones[c.song_id][c.offset] += 1
                    else
                        {% if flag?(:debug) %}
                            puts "Invalid fingerprint hash #{hash}"
                        {% end %}
                    end
                end
            end

            return {matches, timestamps, target_zones}
        end

        # Retrieves all information from the database for each hash
        private def get_candidates(hashes : Array(UInt64)) : Hash(UInt64, Array(Candidate))
            candidates = Hash(UInt64, Array(Candidate)).new { |h, k| h[k] = [] of Candidate }

            statement = @db.prepared("SELECT song, offset FROM fingerprints WHERE hash = ?")
            hashes.each do |hash|
                statement.query(hash.to_i64!) do |rs|
                    rs.each do
                        song_id = rs.read(String)
                        offset = rs.read(Int32).to_u32
                        candidates[hash] << Candidate.new(song_id, offset)
                    end
                end
            end

            return candidates
        end

        # Filters out low-quality matches based on target zone size and threshold
        private def filter_matches(matches : Hash(String, Array(Tuple(UInt32, UInt32))), target_zones : Hash(String, Hash(UInt32, Int32)), threshold : UInt32 = DEFAULT_MATCH_THRESHOLD, target_zone_size : UInt32 = DEFAULT_TARGET_ZONE_SIZE) : Hash(String, Array(Tuple(UInt32, UInt32)))
            # Remove anchor times that don't have enough points within the target zone
            target_zones.each do |song_id, anchor_times|
                anchor_times.reject! { |_, count| count < target_zone_size }
            end

            # Only keep matches for songs that have enough target zones
            filtered_matches = Hash(String, Array(Tuple(UInt32, UInt32))).new
            target_zones.each do |song_id, zones|
                if zones.size >= threshold
                    filtered_matches[song_id] = matches[song_id]
                end
            end

            {% if flag?(:debug) %}
                puts "Filtered out #{matches.size- filtered_matches.size} low-quality matches"
            {% end %}

            return filtered_matches
        end

        # Score matches based on consistency of time differences between matching points
        private def analyze_time_coherence(matches : Hash(String, Array(Tuple(UInt32, UInt32)))) : Hash(String, UInt32)
            scores = Hash(String, UInt32).new

            # Calculate time coherence score for each possible candidate
            matches.each do |song_id, times|
                score = 0
                times.each_with_index do |time_i, i|
                    times[(i + 1)..-1].each do |time_j|
                        # Difference between successive anchor pairs in input
                        sample_diff = (time_i[0].to_i64 - time_j[0].to_i64).abs

                        # Difference between successive anchor pairs in candidate
                        db_diff = (time_i[1].to_i64 - time_j[1].to_i64).abs

                        # If these are within our timing tolerance, increment the score
                        if (sample_diff - db_diff).abs < DEFAULT_TIMING_TOLERANCE
                            score += 1
                        end
                    end
                end
                scores[song_id] = score.to_u32
            end

            return scores
        end
    end
end
