#include "chall_rng.hpp"

#include <random>

// const result_type mersenne_61 = 2305843009213693951;
const ChallRng::result_type mersenne_31 = 2147483647;
const ChallRng::result_type gorp =   0x77777777;

std::random_device rd;

ChallRng::ChallRng(result_type team_seed) {
  m = mersenne_31;
  a = team_seed ^ gorp;
  c = 2021;

  state = rd() ^ gorp;
}

ChallRng::result_type ChallRng::next() {
  state = (a * state + c) % m;
  return state;
}
