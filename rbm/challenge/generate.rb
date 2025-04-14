#!/usr/bin/env ruby

require 'base64'
require 'json'
require 'securerandom'

git_status = `git status --porcelain=v1`
unless git_status.empty? || ENV['YOLO'] == 'you oughta look out'
  puts "Git status is not clean. Please commit or stash your changes."
  exit 1
end

count = (ENV['COUNT'] || '10').to_i
party_idx = rand(0..count - 1)

headers = %w{string array cmath cstddef algorithm cstdint cstring iostream}.sort.uniq

class Template
  @@count = 0

  def name
    return @name if @name
    @@count += 1
    @name = "#{self.class.name.downcase}#{@@count}"
  end
end

class First < Template
  def initialize
    @arr_size = rand(40..80)
    @wanted = SecureRandom.alphanumeric(8)
    @padding = rand(0..4)
    @target = SecureRandom.alphanumeric(8)
  end

  def vulnerable!
    unless 0 == (@arr_size % 2)
      @arr_size += 1
    end
    @padding = 8
  end

  def payload
    ('a' * @arr_size) +
    @wanted.reverse
  end

  def as_json
    {
      name: name,
      arr_size: @arr_size,
      wanted: @wanted,
      padding: @padding,
      target: @target,
      payload: payload,
    }
  end

  def to_cpp
    <<~CPP
      bool #{name}(const std::string &provided) {
        const std::size_t arr_size = #{@arr_size};
        uint64_t target = 0;
        std::array<char, arr_size> arr;
        uint64_t wanted = 0x#{@wanted.unpack('H*').first};
        std::size_t to_copy = std::min(provided.size(), arr_size + #{@padding});

        memcpy(arr.data(), provided.data(), to_copy);

        std::cerr << "target: " << std::hex << target << std::endl;
        std::cerr << "wanted: " << std::hex << wanted << std::endl;

        return target == wanted;
      }
    CPP
  end
end

class Alter < First
  def to_cpp
    <<~CPP
      bool #{name}(const std::string &provided) {
        const std::size_t arr_size = #{@arr_size};
        uint64_t target = 0;
        std::array<char, arr_size> arr;
        uint64_t wanted = 0x#{@wanted.unpack('H*').first};
        std::size_t to_copy = std::min(provided.size(), arr_size + #{@padding});

        for (std::size_t i = 0; i < to_copy / 2; ++i) {
          arr[i] = 
            (provided[i] & 0x0F) | 
            (provided[i + (to_copy / 2)] & 0xF0);
          arr[i + (to_copy / 2)] =
            (provided[i] & 0xF0) | 
            (provided[i + (to_copy / 2)] & 0x0F);
        }

        std::cerr << "target: " << std::hex << target << std::endl;
        std::cerr << "wanted: " << std::hex << wanted << std::endl;

        return target == wanted;
      }
    CPP
  end

  def payload
    start = ('a' * @arr_size) + @wanted.reverse

    chopper = String.new(start)
    (start.size / 2).times do |i|
      chopper[i] = 
        ((start[i].ord & 0x0f) |
        (start[i + (start.size / 2)].ord & 0xf0)).chr
      chopper[i + (start.size / 2)] = 
        ((start[i].ord & 0xf0) |
        (start[i + (start.size / 2)].ord & 0x0f)).chr
    end

    chopper
  end
end

class Palindrome < First
  def to_cpp
    <<~CPP
      bool #{name}(const std::string &provided) {
        if (!palindrome::is_palindrome(provided)) {
          return false;
        }

        const std::size_t arr_size = #{@arr_size};
        uint64_t target = 0;
        std::array<char, arr_size> arr;
        uint64_t wanted = 0x#{@wanted.unpack('H*').first};
        std::size_t to_copy = std::min(provided.size(), arr_size + #{@padding});

        memcpy(arr.data(), provided.data(), to_copy);

        std::cerr << "target: " << std::hex << target << std::endl;
        std::cerr << "wanted: " << std::hex << wanted << std::endl;

        return target == wanted;
      }
    CPP
  end

  def payload
    start = ('a' * @arr_size) + @wanted.reverse

    last_half = start[(start.length / 2)..-1]
    first_half = last_half.reverse

    first_half + last_half
  end
end

class Snake < First
  def initialize
    super
    @width = rand(5..9)
    @height = rand(5..9)
    @arr_size = @width * @height
    @loop_check = "std::min(width * height, provided.size())"
  end

  def vulnerable!
    @loop_check = "provided.size()"
    @width = 8
    @arr_size = @width * @height
  end

  def as_json
    super.merge(
      width: @width,
      height: @height,
    )
  end

  def payload
    start = ('a' * @arr_size) + @wanted
    real_height = (start.size.to_f / @width.to_f).ceil.to_i

    grid = Array.new(real_height) { Array.new(@width) }
    
    # Keep track of our current position in the start string
    char_index = 0
    
    # Fill the grid in a snake pattern
    real_height.times do |row|
      if row.odd?
        (@width - 1).downto(0) do |col|
          break if char_index >= start.length
          grid[row][col] = start[char_index]
          char_index += 1
        end
      else
        0.upto(@width - 1) do |col|
          break if char_index >= start.length
          grid[row][col] = start[char_index]
          char_index += 1
        end
      end
    end

    # Flatten the grid back into a string
    result = ""
    real_height.times do |row|
      result << grid[row].flatten.join
    end
    
    result
  end

  def to_cpp
    <<~CPP
      bool #{name}(const std::string &provided) {
        const std::size_t width = #{@width};
        const std::size_t height = #{@height};
        uint64_t target = 0;
        using row_t = std::array<char, width>;
        std::array<row_t, height> arr;
        uint64_t wanted = 0x#{@wanted.unpack('H*').first};
        
        std::cerr << std::hex << 
          "&arr:\t" << (void*)&arr << std::endl <<
          "&target:\t" << (void*)&target << std::endl <<
          "&target - &arr:\t" << std::dec << (std::ptrdiff_t)(void*)(&target) - (std::ptrdiff_t)(void*)(&arr) << std::endl;

        for (std::size_t pi = 0; pi < #{@loop_check}; pi++) {
          std::size_t dest_row = pi / width;
          std::size_t dest_col = pi % width;
          if (0 == (dest_row % 2)) {
            dest_col = (width - (pi % width)) - 1;
          }

          arr[dest_row][dest_col] = provided[pi];
        }

        for (std::size_t row = 0; row < height; row++) {
          for (std::size_t col = 0; col < width; col++) {
            std::cerr << std::hex << arr[row][col];
          }
          std::cerr << std::endl;
        }

        std::cerr << "target: " << std::hex << target << std::endl;
        std::cerr << "wanted: " << std::hex << wanted << std::endl;

        return target == wanted;
      }
    CPP
  end
end

template_classes = [Alter, Palindrome, First, Snake]

@counts = Hash.new(0)

templates = []

File.open(File.join(__dir__, 'src', 'generated.cpp'), 'w') do |f|
  headers.each do |header|
    f.puts "#include <#{header}>"
  end

  f.puts "#include \"generated.hpp\""
  f.puts "#include \"palindrome.hpp\""

  count.times do |i|
    template = template_classes.sample.new
    @counts[template.class] += 1
    template.vulnerable! if i == party_idx

    f.puts template.to_cpp
    templates << template
  end

  f.puts <<~CPP
    std::vector<fun> get_funs() {
      return {
        #{templates.map { |t| "#{t.name}" }.join(",\n    ")}
      };
    }
  CPP
end

File.open(File.join(__dir__, 'src', 'generated.hpp'), 'w') do |f|
  f.puts <<~CPP
    #pragma once

    #include <functional>
    #include <string>
    #include <vector>

    using fun = std::function<bool(const std::string&)>;

    std::vector<fun> get_funs();
  CPP
end

File.open(File.join(__dir__, '..', 'solver', 'hint.json'), 'w') do |f|
  f.puts JSON.pretty_generate({
    index: party_idx,
    src: templates[party_idx].to_cpp}.merge(templates[party_idx].as_json)
  )
end

File.open(File.join(__dir__, '..', 'solver', 'in'), 'w') do |f|
  f.puts party_idx
  f.puts Base64.strict_encode64(templates[party_idx].payload)
end

@counts.each do |klass, count|
  puts "#{klass.name}\t#{count}"
end
