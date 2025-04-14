#include "palindrome.hpp"

namespace palindrome {
  bool is_palindrome(const std::string& str) {
    // An empty string or single character is always a palindrome
    if (str.size() <= 1) {
      return true;
    }
    
    // Compare bytes from both ends moving inward
    size_t left = 0;
    size_t right = str.size() - 1;
    
    while (left < right) {
      if (str.at(left) != str.at(right)) {
        return false;
      }
      ++left;
      --right;  // Decrement right to move inward from the end
    }
    
    return true;
  }
}
