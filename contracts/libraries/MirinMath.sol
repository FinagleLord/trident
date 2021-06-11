// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

library MirinMath {
    uint256 internal constant ONE = 1;
    uint256 internal constant FIXED_1 = 0x080000000000000000000000000000000;
    uint256 internal constant FIXED_2 = 0x100000000000000000000000000000000;
    uint256 internal constant SQRT_1 = 13043817825332782212;
    uint256 internal constant LNX = 3988425491;
    uint256 internal constant LOG_10_2 = 3010299957;
    uint256 internal constant LOG_E_2 = 6931471806;
    uint256 internal constant BASE10 = 1e10;

    uint256 internal constant MAX_NUM = 0x200000000000000000000000000000000;
    uint8 internal constant MIN_PRECISION = 32;
    uint8 internal constant MAX_PRECISION = 127;
    uint256 internal constant OPT_LOG_MAX_VAL = 0x15bf0a8b1457695355fb8ac404e7a79e3;
    uint256 internal constant OPT_EXP_MAX_VAL = 0x800000000000000000000000000000000;

    uint256 internal constant BASE18 = 1e18;
    uint256 internal constant MIN_POWER_BASE = 1 wei;
    uint256 internal constant MAX_POWER_BASE = (2 * BASE18) - 1 wei;
    uint256 internal constant POWER_PRECISION = BASE18 / 1e10;

    // computes square roots using the babylonian method
    // https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
    // credit for this implementation goes to
    // https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // this block is equivalent to r = uint256(1) << (BitMath.mostSignificantBit(x) / 2);
        // however that code costs significantly more gas
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }

    function ln(uint256 x) internal pure returns (uint256) {
        uint256 res = 0;

        // If x >= 2, then we compute the integer part of log2(x), which is larger than 0.
        if (x >= FIXED_2) {
            uint8 count = floorLog2(x / FIXED_1);
            x >>= count; // now x < 2
            res = count * FIXED_1;
        }

        // If x > 1, then we compute the fraction part of log2(x), which is larger than 0.
        if (x > FIXED_1) {
            for (uint8 i = MAX_PRECISION; i > 0; --i) {
                x = (x * x) / FIXED_1; // now 1 < x < 4
                if (x >= FIXED_2) {
                    x >>= 1; // now 1 < x < 2
                    res += ONE << (i - 1);
                }
            }
        }

        return (res * LOG_E_2) / BASE10;
    }

    /**
     * @dev computes log(x / FIXED_1) * FIXED_1.
     * This functions assumes that "x >= FIXED_1", because the output would be negative otherwise.
     */
    function generalLog(uint256 x) internal pure returns (uint256) {
        uint256 res = 0;

        // If x >= 2, then we compute the integer part of log2(x), which is larger than 0.
        if (x >= FIXED_2) {
            uint8 count = floorLog2(x / FIXED_1);
            x >>= count; // now x < 2
            res = count * FIXED_1;
        }

        // If x > 1, then we compute the fraction part of log2(x), which is larger than 0.
        if (x > FIXED_1) {
            for (uint8 i = MAX_PRECISION; i > 0; --i) {
                x = (x * x) / FIXED_1; // now 1 < x < 4
                if (x >= FIXED_2) {
                    x >>= 1; // now 1 < x < 2
                    res += ONE << (i - 1);
                }
            }
        }

        return (res * LOG_10_2) / BASE10;
    }

    /**
     * @dev computes the largest integer smaller than or equal to the binary logarithm of the input.
     */
    function floorLog2(uint256 _n) internal pure returns (uint8) {
        uint8 res = 0;

        if (_n < 256) {
            // At most 8 iterations
            while (_n > 1) {
                _n >>= 1;
                res += 1;
            }
        } else {
            // Exactly 8 iterations
            for (uint8 s = 128; s > 0; s >>= 1) {
                if (_n >= (ONE << s)) {
                    _n >>= s;
                    res |= s;
                }
            }
        }

        return res;
    }

    /**
     * @dev computes ln(x / FIXED_1) * FIXED_1
     * Input range: FIXED_1 <= x <= OPT_LOG_MAX_VAL - 1
     * Auto-generated via 'PrintFunctionOptimalLog.py'
     * Detailed description:
     * - Rewrite the input as a product of natural exponents and a single residual r, such that 1 < r < 2
     * - The natural logarithm of each (pre-calculated) exponent is the degree of the exponent
     * - The natural logarithm of r is calculated via Taylor series for log(1 + x), where x = r - 1
     * - The natural logarithm of the input is calculated by summing up the intermediate results above
     * - For example: log(250) = log(e^4 * e^1 * e^0.5 * 1.021692859) = 4 + 1 + 0.5 + log(1 + 0.021692859)
     */
    function optimalLog(uint256 x) internal pure returns (uint256) {
        require(FIXED_1 <= x, "MIRIN: OVERFLOW");
        uint256 res = 0;

        uint256 y;
        uint256 z;
        uint256 w;

        if (x >= 0xd3094c70f034de4b96ff7d5b6f99fcd8) {
            res += 0x40000000000000000000000000000000;
            x = (x * FIXED_1) / 0xd3094c70f034de4b96ff7d5b6f99fcd8;
        } // add 1 / 2^1
        if (x >= 0xa45af1e1f40c333b3de1db4dd55f29a7) {
            res += 0x20000000000000000000000000000000;
            x = (x * FIXED_1) / 0xa45af1e1f40c333b3de1db4dd55f29a7;
        } // add 1 / 2^2
        if (x >= 0x910b022db7ae67ce76b441c27035c6a1) {
            res += 0x10000000000000000000000000000000;
            x = (x * FIXED_1) / 0x910b022db7ae67ce76b441c27035c6a1;
        } // add 1 / 2^3
        if (x >= 0x88415abbe9a76bead8d00cf112e4d4a8) {
            res += 0x08000000000000000000000000000000;
            x = (x * FIXED_1) / 0x88415abbe9a76bead8d00cf112e4d4a8;
        } // add 1 / 2^4
        if (x >= 0x84102b00893f64c705e841d5d4064bd3) {
            res += 0x04000000000000000000000000000000;
            x = (x * FIXED_1) / 0x84102b00893f64c705e841d5d4064bd3;
        } // add 1 / 2^5
        if (x >= 0x8204055aaef1c8bd5c3259f4822735a2) {
            res += 0x02000000000000000000000000000000;
            x = (x * FIXED_1) / 0x8204055aaef1c8bd5c3259f4822735a2;
        } // add 1 / 2^6
        if (x >= 0x810100ab00222d861931c15e39b44e99) {
            res += 0x01000000000000000000000000000000;
            x = (x * FIXED_1) / 0x810100ab00222d861931c15e39b44e99;
        } // add 1 / 2^7
        if (x >= 0x808040155aabbbe9451521693554f733) {
            res += 0x00800000000000000000000000000000;
            x = (x * FIXED_1) / 0x808040155aabbbe9451521693554f733;
        } // add 1 / 2^8

        z = y = x - FIXED_1;
        w = (y * y) / FIXED_1;
        res += (z * (0x100000000000000000000000000000000 - y)) / 0x100000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^01 / 01 - y^02 / 02
        res += (z * (0x0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa - y)) / 0x200000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^03 / 03 - y^04 / 04
        res += (z * (0x099999999999999999999999999999999 - y)) / 0x300000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^05 / 05 - y^06 / 06
        res += (z * (0x092492492492492492492492492492492 - y)) / 0x400000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^07 / 07 - y^08 / 08
        res += (z * (0x08e38e38e38e38e38e38e38e38e38e38e - y)) / 0x500000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^09 / 09 - y^10 / 10
        res += (z * (0x08ba2e8ba2e8ba2e8ba2e8ba2e8ba2e8b - y)) / 0x600000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^11 / 11 - y^12 / 12
        res += (z * (0x089d89d89d89d89d89d89d89d89d89d89 - y)) / 0x700000000000000000000000000000000;
        z = (z * w) / FIXED_1; // add y^13 / 13 - y^14 / 14
        res += (z * (0x088888888888888888888888888888888 - y)) / 0x800000000000000000000000000000000; // add y^15 / 15 - y^16 / 16

        return res;
    }

    /**
     * @dev computes e ^ (x / FIXED_1) * FIXED_1
     * input range: 0 <= x <= OPT_EXP_MAX_VAL - 1
     * auto-generated via 'PrintFunctionOptimalExp.py'
     * Detailed description:
     * - Rewrite the input as a sum of binary exponents and a single residual r, as small as possible
     * - The exponentiation of each binary exponent is given (pre-calculated)
     * - The exponentiation of r is calculated via Taylor series for e^x, where x = r
     * - The exponentiation of the input is calculated by multiplying the intermediate results above
     * - For example: e^5.521692859 = e^(4 + 1 + 0.5 + 0.021692859) = e^4 * e^1 * e^0.5 * e^0.021692859
     */
    function optimalExp(uint256 x) internal pure returns (uint256) {
        require(x <= OPT_EXP_MAX_VAL - 1, "MIRIN: OVERFLOW");
        uint256 res = 0;

        uint256 y;
        uint256 z;

        z = y = x % 0x10000000000000000000000000000000; // get the input modulo 2^(-3)
        z = (z * y) / FIXED_1;
        res += z * 0x10e1b3be415a0000; // add y^02 * (20! / 02!)
        z = (z * y) / FIXED_1;
        res += z * 0x05a0913f6b1e0000; // add y^03 * (20! / 03!)
        z = (z * y) / FIXED_1;
        res += z * 0x0168244fdac78000; // add y^04 * (20! / 04!)
        z = (z * y) / FIXED_1;
        res += z * 0x004807432bc18000; // add y^05 * (20! / 05!)
        z = (z * y) / FIXED_1;
        res += z * 0x000c0135dca04000; // add y^06 * (20! / 06!)
        z = (z * y) / FIXED_1;
        res += z * 0x0001b707b1cdc000; // add y^07 * (20! / 07!)
        z = (z * y) / FIXED_1;
        res += z * 0x000036e0f639b800; // add y^08 * (20! / 08!)
        z = (z * y) / FIXED_1;
        res += z * 0x00000618fee9f800; // add y^09 * (20! / 09!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000009c197dcc00; // add y^10 * (20! / 10!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000000e30dce400; // add y^11 * (20! / 11!)
        z = (z * y) / FIXED_1;
        res += z * 0x000000012ebd1300; // add y^12 * (20! / 12!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000000017499f00; // add y^13 * (20! / 13!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000000001a9d480; // add y^14 * (20! / 14!)
        z = (z * y) / FIXED_1;
        res += z * 0x00000000001c6380; // add y^15 * (20! / 15!)
        z = (z * y) / FIXED_1;
        res += z * 0x000000000001c638; // add y^16 * (20! / 16!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000000000001ab8; // add y^17 * (20! / 17!)
        z = (z * y) / FIXED_1;
        res += z * 0x000000000000017c; // add y^18 * (20! / 18!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000000000000014; // add y^19 * (20! / 19!)
        z = (z * y) / FIXED_1;
        res += z * 0x0000000000000001; // add y^20 * (20! / 20!)
        res = res / 0x21c3677c82b40000 + y + FIXED_1; // divide by 20! and then add y^1 / 1! + y^0 / 0!

        if ((x & 0x010000000000000000000000000000000) != 0)
            res = (res * 0x1c3d6a24ed82218787d624d3e5eba95f9) / 0x18ebef9eac820ae8682b9793ac6d1e776; // multiply by e^2^(-3)
        if ((x & 0x020000000000000000000000000000000) != 0)
            res = (res * 0x18ebef9eac820ae8682b9793ac6d1e778) / 0x1368b2fc6f9609fe7aceb46aa619baed4; // multiply by e^2^(-2)
        if ((x & 0x040000000000000000000000000000000) != 0)
            res = (res * 0x1368b2fc6f9609fe7aceb46aa619baed5) / 0x0bc5ab1b16779be3575bd8f0520a9f21f; // multiply by e^2^(-1)
        if ((x & 0x080000000000000000000000000000000) != 0)
            res = (res * 0x0bc5ab1b16779be3575bd8f0520a9f21e) / 0x0454aaa8efe072e7f6ddbab84b40a55c9; // multiply by e^2^(+0)
        if ((x & 0x100000000000000000000000000000000) != 0)
            res = (res * 0x0454aaa8efe072e7f6ddbab84b40a55c5) / 0x00960aadc109e7a3bf4578099615711ea; // multiply by e^2^(+1)
        if ((x & 0x200000000000000000000000000000000) != 0)
            res = (res * 0x00960aadc109e7a3bf4578099615711d7) / 0x0002bf84208204f5977f9a8cf01fdce3d; // multiply by e^2^(+2)
        if ((x & 0x400000000000000000000000000000000) != 0)
            res = (res * 0x0002bf84208204f5977f9a8cf01fdc307) / 0x0000003c6ab775dd0b95b4cbee7e65d11; // multiply by e^2^(+3)

        return res;
    }

    function toInt(uint256 a) internal pure returns (uint256) {
        return a / BASE18;
    }

    function toFloor(uint256 a) internal pure returns (uint256) {
        return toInt(a) * BASE18;
    }

    function roundMul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c0 = a * b;
        uint256 c1 = c0 + (BASE18 / 2);
        return c1 / BASE18;
    }

    function roundDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c0 = a * BASE18;
        uint256 c1 = c0 + (b / 2);
        return c1 / b;
    }

    function power(uint256 base, uint256 exp) internal pure returns (uint256) {
        require(base >= MIN_POWER_BASE, "MIRIN: POWER_BASE_TOO_LOW");
        require(base <= MAX_POWER_BASE, "MIRIN: POWER_BASE_TOO_HIGH");

        uint256 whole = toFloor(exp);
        uint256 remain = exp - whole;

        uint256 wholePow = powInt(base, toInt(whole));

        if (remain == 0) {
            return wholePow;
        }

        uint256 partialResult = powFrac(base, remain, POWER_PRECISION);
        return roundMul(wholePow, partialResult);
    }

    function powInt(uint256 a, uint256 n) private pure returns (uint256) {
        uint256 z = n % 2 != 0 ? a : BASE18;

        for (n /= 2; n != 0; n /= 2) {
            a = roundMul(a, a);

            if (n % 2 != 0) {
                z = roundMul(z, a);
            }
        }
        return z;
    }

    function powFrac(
        uint256 base,
        uint256 exp,
        uint256 precision
    ) private pure returns (uint256) {
        uint256 a = exp;
        (uint256 x, bool xneg) = base >= BASE18 ? (base - BASE18, false) : (BASE18 - base, true);
        uint256 term = BASE18;
        uint256 sum = term;
        bool negative = false;

        for (uint256 i = 1; term >= precision; i++) {
            uint256 bigK = i * BASE18;
            (uint256 c, bool cneg) = a + BASE18 >= bigK ? (a + BASE18 - bigK, false) : (bigK - a - BASE18, true);
            term = roundMul(term, roundMul(c, x));
            term = roundDiv(term, bigK);
            if (term == 0) break;

            if (xneg) negative = !negative;
            if (cneg) negative = !negative;
            if (negative) {
                sum = sum - term;
            } else {
                sum = sum + term;
            }
        }
        return sum;
    }

/*    // 1 in fixed 128bit arithmetic
    uint256 internal constant FP_1 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    // power function in fixed 128bit arithmetic
    function powInt128(uint256 a128, uint8 n) internal pure returns (uint256) {
        uint256 z = n % 2 != 0 ? a128 : FP_1;

        for (n /= 2; n != 0; n /= 2) {
            a128 = ((a128 * a128) >> 128 ) + 1;

            if (n % 2 != 0) {
                z = ((z * a128) >> 128 ) + 1;
            }
        }
        return z;
    }

    // the place of the most high not-zero bit, starting from 0
    function msb (uint256 _x) internal pure returns (uint8) {
        require (_x > 0, "msb() input error");
        uint8 result = 0;

        if (_x >= 0x100000000000000000000000000000000) { _x >>= 128; result += 128; }
        if (_x >= 0x10000000000000000) { _x >>= 64; result += 64; }
        if (_x >= 0x100000000) { _x >>= 32; result += 32; }
        if (_x >= 0x10000) { _x >>= 16; result += 16; }
        if (_x >= 0x100) { _x >>= 8; result += 8; }
        if (_x >= 0x10) { _x >>= 4; result += 4; }
        if (_x >= 0x4) { _x >>= 2; result += 2; }
        if (_x >= 0x2) result += 1; // No need to shift _x anymore

        return result;
    }
    
    // power function in fixed 128bit arithmetic
    function sqrt128(uint256 x128) internal pure returns (uint256) {
        if (x128 == 0) return 0;
        x128 <<= 128;
        uint256 r = FP_1;
        r = (r + x128 / r) >> 1;
        r = (r + x128 / r) >> 1;
        r = (r + x128 / r) >> 1;
        r = (r + x128 / r) >> 1;
        r = (r + x128 / r) >> 1;
        r = (r + x128 / r) >> 1;
        r = (r + x128 / r) >> 1; // Seven iterations should be enough
        return r;
    }*/


    uint256 internal constant FP_1 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function fPfromUint(uint256 n) internal pure returns (uint256 mant, int256 exp) {
        unchecked {
            exp = int256(uint256(msb(n))) - 127;    // No under/overflow because 0 <= msb <= 255
            mant = exp >= 0 ? n >> uint256(exp) : n << uint256(-exp);   // shifts are not checked by EVM for under/overflow
        }
    }

    // Attention!!! overflow is value is more than 2^256 - 1 !!!
    function fPtoUint(uint256 mant, int256 exp) internal pure returns (uint256 n) {
        n = exp >= 0 ? mant << uint256(exp) : mant >> uint256(-exp);
    }

    function fPmul(uint256 m1, int256 e1, uint256 m2, int256 e2) internal pure returns (uint256 m, int256 e) {
        unchecked {
            m = m1*m2;
            e = e1 + e2;
            if ( (m >> 255) == 0) {
                m = (m >> 127) + 1; //?
                e += 127;
            } else {
                m = (m >> 128) + 1; //?
                e += 128;
            }
        }
    }

    function fPpow(uint256 m, int256 e, uint8 n) internal pure returns (uint256 mp, int256 ep) {
        unchecked {     // No place for under/overcorrection
            if (n % 2 != 0) {
                mp = m;
                ep = e;
            } else {
                mp = FP_1;
                ep = -128;
            }

            for (n /= 2; n != 0; n /= 2) {
                (m, e) = fPmul(m, e, m, e);

                if (n % 2 != 0) {
                    (mp, ep) = fPmul(mp, ep, m, e);
                }
            }
        }
    }

    /**
   * Get index of the most significant non-zero bit in binary representation of
   * x.  Reverts if x is zero.
   *
   * @return index of the most significant non-zero bit in binary representation
   *         of x
   */
    function msb (uint256 _x) private pure returns (uint8) {
        unchecked {
            //require (_x > 0);
            uint8 result = 0;

            if (_x >= 0x100000000000000000000000000000000) { _x >>= 128; result += 128; }
            if (_x >= 0x10000000000000000) { _x >>= 64; result += 64; }
            if (_x >= 0x100000000) { _x >>= 32; result += 32; }
            if (_x >= 0x10000) { _x >>= 16; result += 16; }
            if (_x >= 0x100) { _x >>= 8; result += 8; }
            if (_x >= 0x10) { _x >>= 4; result += 4; }
            if (_x >= 0x4) { _x >>= 2; result += 2; }
            if (_x >= 0x2) result += 1; // No need to shift _x anymore

            return result;
        }
    }

    function fPsqrt(uint256 x, int256 shift) internal pure returns (uint256 r, int256 shiftR) {
        unchecked {
            if (shift%2 == 0) {
                x <<= 128;
                shiftR = (shift - 128)/2;
            } else {
                x <<= 127;
                shiftR = (shift - 127)/2;
            }
            r = FP_1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1; // Seven iterations should be enough
        }
    }
}
