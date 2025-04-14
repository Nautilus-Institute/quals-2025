#pragma once

#include <cstdint>

class ChallRng {
public:
    using result_type = uint32_t;

    ChallRng(result_type team_seed);
    ChallRng(result_type candidate_team_seed, result_type given_seed);

    result_type next();

private:
  result_type a, c, m, state;
};

const ChallRng::result_type mersenne_31 = 2147483647;
const ChallRng::result_type gorp =   0x77777777;
