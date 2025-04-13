require "./wav"

module EchoID
    # Represents a complex number
    struct Complex
        property real : Float64
        property imag : Float64

        def initialize(@real : Float64, @imag : Float64)
        end

        def +(other : Complex)
            Complex.new(@real + other.real, @imag + other.imag)
        end

        def -(other : Complex)
            Complex.new(@real - other.real, @imag - other.imag)
        end

        def *(other : Complex)
            r = @real * other.real - @imag * other.imag
            i = @real * other.imag + @imag * other.real
            Complex.new(r, i)
        end

        def abs
            Math.sqrt(@real * @real + @imag * @imag)
        end
    end

    # Represents an identified peak in a spectrogram
    struct Peak
        property time : UInt32  # Position of the peak
        property freq : UInt32  # Frequency of the peak
        property amp : Float64  # Magnitude of the peak

        def initialize(@time : UInt32, @freq : UInt32, @amp : Float64)
        end
    end

    # Represents a unique fingerprint for a single slice of audio
    struct Fingerprint
        property hash : UInt64          # Hash value uniquely identifying this fingerprint
        property anchor_time : Float64  # Time of the anchor point in milliseconds
        property anchor_freq : Float64  # Frequency of the anchor point in Hz
        property target_time : Float64  # Time of the target point in milliseconds
        property target_freq : Float64  # Frequency of the target point in Hz
        property delta_time : Float64   # Time difference in milliseconds between anchor and target

        def initialize(@anchor_time, @anchor_freq, @target_time, @target_freq, @delta_time)
            @hash = (@anchor_freq.to_u64 << 40) | (@target_freq.to_u64 << 20) | @delta_time.to_u64
            @hash &= 0x7FFFFFFF # Storing this as signed in database, need to ensure top bit is unset
        end
    end

    # Handles audio file loading, filtering, and processing
    class AudioProcessor
        DEFAULT_HIGH_PASS_CUTOFF = 20.0     # Human ears can't perceive tone below 20Hz
        DEFAULT_LOW_PASS_CUTOFF = 5000.0    # Human ears are not as sensitive above 5kHz
        DEFAULT_TARGET_RATE = 11025_u32     # Target sample rate is 44100Hz // 4
        DEFAULT_WINDOW_SIZE = 1024_u32      # Size of FFT frame in samples
        DEFAULT_HOP_SIZE = 64_u32           # Size of FFT stride in samples (density)
        DEFAULT_REGION_SIZE = 20            # Number of neighboring frequency bins to consider
        DEFAULT_PEAK_THRESHOLD = 10.0       # Minimum amplitude required to be a peak
        DEFAULT_PROMINENCE_THRESHOLD = 4.0  # Peaks must be this far above other peaks to count
        DEFAULT_FAN_VALUE = 15_u32          # Number of target points per anchor
        DEFAULT_MIN_DELTA_TIME = 0.1        # Minimum time between anchor point and target point (seconds)
        DEFAULT_MAX_DELTA_TIME = 3.0        # Maximum time between anchor point and target point (seconds)
        DEFAULT_TARGET_ZONE_SIZE = 4_u32    # Number of bins to look above and below the anchor frequency

        def initialize
        end

        # Downsample the audio data to a target sample rate
        def downsample(data : Array(Float64), original_sample_rate : UInt32, target_sample_rate : UInt32 = DEFAULT_TARGET_RATE)
            {% if flag?(:debug) %}
                puts "Downsampling from #{original_sample_rate} Hz to #{target_sample_rate} Hz"
            {% end %}

            if target_sample_rate > original_sample_rate
                raise "Cannot downsample from a smaller original sample rate to a higher target sample rate"
            end

            # Apply a high pass and a low pass filter to prevent aliasing
            data = hp_filter(data, original_sample_rate)
            data = lp_filter(data, original_sample_rate)

            # Downsample the audio using linear interpolation
            ratio = original_sample_rate.to_f / target_sample_rate.to_f
            new_size = (data.size / ratio).to_i
            downsampled = Array(Float64).new(new_size, 0.0)
            new_size.times do |i|
                t = i * ratio
                i1 = t.floor.to_i
                i2 = [i1 + 1, data.size - 1].min
                t -= i1

                downsampled[i] = (1 - t) * data[i1] + t * data[i2]
            end

            return downsampled
        end

        # Applies a high-pass filter
        private def hp_filter(data : Array(Float64), sample_rate : UInt32, cutoff : Float64 = DEFAULT_HIGH_PASS_CUTOFF)
            {% if flag?(:debug) %}
                puts "Applying high-pass filter with cutoff frequency: #{cutoff} Hz"
            {% end %}

            # Calculate alpha for the first-order IIR high-pass filter
            dt = 1.0 / sample_rate
            rc = 1.0 / (2 * Math::PI * cutoff)
            alpha = rc / (rc + dt)

            # Filter the audio
            filtered = Array(Float64).new(data.size, 0.0)
            filtered[0] = data[0]  # Use first sample as is
            (1...data.size).each do |i|
                filtered[i] = alpha * (filtered[i - 1] + data[i] - data[i - 1])
            end

            return filtered
        end

        # Applies a low-pass filter
        private def lp_filter(data : Array(Float64), sample_rate : UInt32, cutoff : Float64 = DEFAULT_LOW_PASS_CUTOFF)
            {% if flag?(:debug) %}
                puts "Applying low-pass filter with cutoff frequency: #{cutoff} Hz"
            {% end %}

            # Ensure cutoff is not too close to Nyquist frequency
            max_cutoff = sample_rate / 2.1
            cutoff = cutoff.clamp(0.0, max_cutoff)

            # Calculate alpha for the first-order IIR low-pass filter
            alpha = 1 - Math.exp(-2 * Math::PI * cutoff / sample_rate)

            # Filter the audio
            filtered = Array(Float64).new(data.size, 0.0)
            filtered[0] = data[0]  # Use first sample as is
            (1...data.size).each do |i|
                filtered[i] = (alpha * data[i] + (1 - alpha) * filtered[i - 1]) / (1 - alpha)
            end

            return filtered
        end

        # Compute spectrogram from audio data
        def create_spectrogram(data : Array(Float64), sample_rate : UInt32 = DEFAULT_TARGET_RATE, window_size : UInt32 = DEFAULT_WINDOW_SIZE, hop_size : UInt32 = DEFAULT_HOP_SIZE) : Array(Array(Float64))
            {% if flag?(:debug) %}
                puts "Computing spectrogram with:"
                puts "  Window size: #{window_size} samples (#{window_size.to_f / sample_rate * 1000.0} milliseconds)"
                puts "  Hop size: #{hop_size} samples (#{hop_size.to_f / sample_rate * 1000.0} milliseconds)"
            {% end %}

            raise "Data size must be greater than window size" if data.size < window_size

            # Ensure window_size is a power of 2
            fft_size = window_size.next_power_of_two
            {% if flag?(:debug) %}
                if fft_size != window_size
                    puts "  Adjusted FFT size: #{fft_size} samples (next power of 2)"
                end
            {% end %}

            # Generate Hamming window function
            window = Array.new(window_size) { |i| 0.54 - 0.46 * Math.cos(2 * Math::PI * i / (window_size - 1)) }

            # Calculate number of frames and frequency bins
            num_frames = (((data.size - window_size) / hop_size) + 1).to_u32
            num_bins = window_size // 2 + 1

            # Pre-allocate spectrogram matrix
            spectrogram = Array.new(num_frames) { Array.new(num_bins, 0.0) }

            # Pre-allocate arrays for FFT computation
            complex_frame = Array.new(fft_size) { Complex.new(0.0, 0.0) }
            fft_result = Array.new(fft_size) { Complex.new(0.0, 0.0) }

            # Process each frame
            num_frames.times do |frame|
                start_idx = frame * hop_size
                frame_data = data[start_idx...(start_idx + window_size)]

                # Apply window function and prepare for FFT
                window_size.times do |i|
                    complex_frame[i] = Complex.new(frame_data[i] * window[i], 0.0)
                end

                # Compute FFT (zero-pad input if necessary)
                (window_size...fft_size).each do |i|
                    complex_frame[i] = Complex.new(0.0, 0.0)
                end
                fft(complex_frame, fft_result)

                # Compute magnitude spectrum (excluding DC and Nyquist)
                (1...num_bins - 1).each do |bin|
                    magnitude = fft_result[bin].abs
                    spectrogram[frame][bin] = 20 * Math.log10(magnitude + 1e-10)
                end
            end

            return spectrogram
        end

        # Iterative in-place FFT implementation (Cooley-Tukey radix-2 DIT, assumes power of 2)
        private def fft(x : Array(Complex), result : Array(Complex))
            n = x.size
            n.times { |i| result[i] = x[i] }

            # Bit reversal
            j = 0
            n1 = n - 1
            (1...n1).each do |i|
                bit = n >> 1
                while j & bit != 0
                    j ^= bit
                    bit >>= 1
                end
                j ^= bit
                if i < j
                    result[i], result[j] = result[j], result[i]
                end
            end

            # Butterfly
            mmax = 1
            while n > mmax
                istep = mmax << 1
                theta = -Math::PI / mmax
                wpr = -2.0 * (Math.sin(0.5 * theta)) ** 2
                wpi = Math.sin(theta)
                wr = 1.0
                wi = 0.0
                (0...mmax).each do |m|
                    (m...n).step(istep) do |i|
                        j = i + mmax
                        tempr = wr * result[j].real - wi * result[j].imag
                        tempi = wr * result[j].imag + wi * result[j].real
                        result[j] = Complex.new(result[i].real - tempr, result[i].imag - tempi)
                        result[i] += Complex.new(tempr, tempi)
                    end
                    wtemp = wr
                    wr += wr * wpr - wi * wpi
                    wi += wi * wpr + wtemp * wpi
                end
                mmax = istep
            end
        end

        # Extract peaks from the spectrogram
        def extract_peaks(spectrogram : Array(Array(Float64)), sample_rate : UInt32 = DEFAULT_TARGET_RATE, hop_size : UInt32 = DEFAULT_HOP_SIZE, threshold : Float64 = DEFAULT_PEAK_THRESHOLD, region_size : Int32 = DEFAULT_REGION_SIZE) : Array(Peak)
            {% if flag?(:debug) %}
                puts "Extracting peaks from spectrogram"
                puts "  Region size: #{region_size}"
                puts "  Threshold: #{threshold} dB"
            {% end %}

            peaks = [] of Peak
            num_frames = spectrogram.size
            num_bins = spectrogram[0].size

            # Find all peaks within each frequency bin
            (region_size...num_frames - region_size).each do |t|
                (region_size...num_bins - region_size).each do |f|
                    if is_peak?(spectrogram, threshold, region_size, t, f)
                        amplitude = spectrogram[t][f]
                        time = (t * hop_size).to_u32
                        frequency = (f * sample_rate / (2 * num_bins)).to_u32
                        peaks << Peak.new(time, frequency, amplitude)
                    end
                end
            end

            {% if flag?(:debug) %}
                puts "Extracted #{peaks.size} peaks"
            {% end %}

            return peaks
        end

        # Determines if a particular bin within the spectrogram is a peak
        private def is_peak?(spectrogram : Array(Array(Float64)), threshold : Float64, region_size : Int32, t : Int32, f : Int32) : Bool
            # Check if the amplitude is above the threshold
            amplitude = spectrogram[t][f]
            return false if amplitude < threshold

            # Check if it's a local maximum in both time and frequency
            (-region_size..region_size).each do |dt|
                (-region_size..region_size).each do |df|
                    next if dt == 0 && df == 0
                    if spectrogram[t + dt][f + df] > amplitude
                        return false
                    end
                end
            end

            # Check if the prominence is above the threshold
            min_amplitude = spectrogram[t-region_size..t+region_size].flatten.min
            prominence = amplitude - min_amplitude
            return prominence >= DEFAULT_PROMINENCE_THRESHOLD
        end

        # Generates fingerprints from identified peaks
        def generate_fingerprints(peaks : Array(Peak), sample_rate : UInt32 = DEFAULT_TARGET_RATE, hop_size : UInt32 = DEFAULT_HOP_SIZE, fan_value : UInt32 = DEFAULT_FAN_VALUE, min_delta_time : Float64 = DEFAULT_MIN_DELTA_TIME, max_delta_time : Float64 = DEFAULT_MAX_DELTA_TIME, target_zone_size : UInt32 = DEFAULT_TARGET_ZONE_SIZE) : Array(Fingerprint)
            {% if flag?(:debug) %}
                puts "Generating fingerprints from #{peaks.size} peaks"
                puts "  Fan value: #{fan_value}"
                puts "  Min delta time: #{min_delta_time} seconds"
                puts "  Max delta time: #{max_delta_time} seconds"
                puts "  Target zone size: #{target_zone_size} bins"
            {% end %}

            fingerprints = [] of Fingerprint

            # Convert time parameters to sample counts
            min_delta_samples = (min_delta_time * sample_rate).to_u32
            max_delta_samples = (max_delta_time * sample_rate).to_u32

            # Process each peak as a potential anchor point
            peaks.each do |anchor|
                # Look for matching points within the target zone
                target_points = find_target_points(peaks, anchor, min_delta_samples, max_delta_samples, fan_value)

                # Generate fingerprints from the anchor and its target points
                target_points.each do |target|
                    fingerprints << Fingerprint.new(
                        anchor_time: anchor.time.to_f / sample_rate * 1000,
                        anchor_freq: anchor.freq.to_f,
                        target_time: target.time.to_f / sample_rate * 1000,
                        target_freq: target.freq.to_f,
                        delta_time: target.time - anchor.time
                    )
                end
            end

            {% if flag?(:debug) %}
                puts "Generated #{fingerprints.size} fingerprints"
            {% end %}

            return fingerprints
        end

        # Find appropriate target points for a given anchor point
        private def find_target_points(peaks : Array(Peak), anchor : Peak, min_delta_samples : UInt32, max_delta_samples : UInt32, fan_value : UInt32) : Array(Peak)
            targets = [] of Peak

            # Filter peaks by time range
            candidates = peaks.select do |peak|
                if peak.time >= anchor.time
                    delta_samples = peak.time - anchor.time
                    delta_samples >= min_delta_samples && delta_samples <= max_delta_samples
                else
                    # Ignore peaks that come before the anchor
                    false
                end
            end

            # Sort by time (earliest first)
            candidates.sort_by! { |peak| peak.time }

            # Take the first fan_value peaks or all if less than fan_value
            targets = candidates.first(fan_value)

            return targets
        end
    end
end
