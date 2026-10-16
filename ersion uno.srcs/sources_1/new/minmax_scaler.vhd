
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity minmax_scaler is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9
    );
    port (
        -- Value to normalize, in signed fixed-point format.
        x     : in  SIGNED(DATA_WIDTH - 1 downto 0);

        -- Configurable minimum and maximum of the original range.
        x_min : in  SIGNED(DATA_WIDTH - 1 downto 0);
        x_max : in  SIGNED(DATA_WIDTH - 1 downto 0);

        -- Normalized output, intended to be in [-1, 1].
        y     : out SIGNED(DATA_WIDTH - 1 downto 0)
    );
end minmax_scaler;

architecture Behavioral of minmax_scaler is

    -- Extra bits provide room for intermediate calculations.
    -- This avoids losing precision when multiplying by 2**FRAC_BITS.
    constant CALC_WIDTH : positive :=
        2 * DATA_WIDTH + FRAC_BITS + 2;

    -- In our fixed-point format, real 1.0 is stored as 2**FRAC_BITS.
    constant SCALE_FACTOR : positive := 2**FRAC_BITS;

    -- Output limits: +1.0 and -1.0.
    constant POS_ONE : SIGNED(DATA_WIDTH - 1 downto 0) :=
        to_signed(SCALE_FACTOR, DATA_WIDTH);

    constant NEG_ONE : SIGNED(DATA_WIDTH - 1 downto 0) :=
        to_signed(-SCALE_FACTOR, DATA_WIDTH);

begin

    -- Combinational scaler: no clock or internal state is required.
    process(x, x_min, x_max)

        -- Centered value: 2*x - x_min - x_max.
        variable centered : SIGNED(DATA_WIDTH + 1 downto 0);

        -- Wide intermediate values prevent premature overflow.
        variable numerator   : SIGNED(CALC_WIDTH - 1 downto 0);
        variable denominator : SIGNED(CALC_WIDTH - 1 downto 0);
        variable scaled_value : SIGNED(CALC_WIDTH - 1 downto 0);

    begin

        -- Guard against an invalid or zero-width range.
        -- If x_max <= x_min, return zero instead of dividing by zero.
        if x_max <= x_min then

            y <= (others => '0');

        else

            -- Rearranged min-max formula:
            --
            -- y_real = 2*(x-x_min)/(x_max-x_min) - 1
            --
            -- In fixed-point integer representation:
            --
            -- y_raw = SCALE_FACTOR *
            --         (2*x - x_min - x_max) / (x_max - x_min)

            centered :=
                shift_left(resize(x, DATA_WIDTH + 2), 1)
                - resize(x_min, DATA_WIDTH + 2)
                - resize(x_max, DATA_WIDTH + 2);

            -- Multiply by 512 (for FRAC_BITS = 9) without
            -- discarding fractional precision.
            numerator :=
                shift_left(resize(centered, CALC_WIDTH), FRAC_BITS);

            -- Compute the original range width.
            denominator :=
                resize(x_max, CALC_WIDTH)
                - resize(x_min, CALC_WIDTH);

            -- Signed integer division.
            -- The result is still in our fixed-point representation.
            scaled_value := numerator / denominator;

            -- Clamp values outside the configured range to [-1, 1].
            if scaled_value > to_signed(SCALE_FACTOR, CALC_WIDTH) then

                y <= POS_ONE;

            elsif scaled_value < to_signed(-SCALE_FACTOR, CALC_WIDTH) then

                y <= NEG_ONE;

            else

                -- Convert the safely bounded result to output width.
                y <= resize(scaled_value, DATA_WIDTH);

            end if;

        end if;

    end process;

end Behavioral;
