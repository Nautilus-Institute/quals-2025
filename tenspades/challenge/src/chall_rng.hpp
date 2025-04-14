#pragma once

#include <cstdint>

class ChallRng {
public:
    using result_type = uint32_t;

    ChallRng(result_type team_seed);

    result_type next();

private:
  result_type a, c, m, state;
};