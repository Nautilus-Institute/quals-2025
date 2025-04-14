#include "chall_rng.hpp"

#include <random>

// const result_type mersenne_61 = 2305843009213693951;

std::random_device rd;

ChallRng::ChallRng(result_type team_seed) {
  m = mersenne_31;
  a = team_seed ^ gorp;
  c = 2021;

  state = rd() ^ gorp;
}

ChallRng::ChallRng(result_type candidate_team_seed, result_type given_seed) {
  m = mersenne_31;
  a = candidate_team_seed ^ gorp;
  c = 2021;

  state = given_seed;
}

ChallRng::result_type ChallRng::next() {
  state = (a * state + c) % m;
  return state;
}
