
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Saturating fixed-point multiplier.
--
-- Default format:
--   DATA_WIDTH = 16
--   FRAC_BITS  = 9
--
-- The full product has twice the input width.
-- We shift right by FRAC_BITS to restore the original scale,
-- then clamp the result if it does not fit in DATA_WIDTH bits.

entity fixed_multiplier is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9
    );
    port (
        a      : in  signed(DATA_WIDTH - 1 downto 0);
        b      : in  signed(DATA_WIDTH - 1 downto 0);
        result : out signed(DATA_WIDTH - 1 downto 0)
    );
end fixed_multiplier;

architecture Behavioral of fixed_multiplier is

    -- Maximum positive signed value.
    constant MAX_VALUE : signed(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '0', others => '1');

    -- Minimum negative signed value.
    constant MIN_VALUE : signed(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '1', others => '0');

    -- Full product of two DATA_WIDTH-bit signed numbers.
    signal full_product :
        signed((2 * DATA_WIDTH) - 1 downto 0);

    -- Product after restoring the original fractional precision.
    signal scaled_product :
        signed((2 * DATA_WIDTH) - 1 downto 0);

begin

    -- Calculate the full-precision signed product.
    full_product <= a * b;

    -- Remove the extra fractional bits.
    -- Arithmetic right shift preserves the sign.
    scaled_product <= shift_right(full_product, FRAC_BITS);

    process(scaled_product)
        variable max_extended :
            signed((2 * DATA_WIDTH) - 1 downto 0);

        variable min_extended :
            signed((2 * DATA_WIDTH) - 1 downto 0);
    begin

        -- Extend the limits to the intermediate result width.
        max_extended := resize(MAX_VALUE, 2 * DATA_WIDTH);
        min_extended := resize(MIN_VALUE, 2 * DATA_WIDTH);

        -- Positive overflow: clamp to the maximum.
        if scaled_product > max_extended then
            result <= MAX_VALUE;

        -- Negative overflow: clamp to the minimum.
        elsif scaled_product < min_extended then
            result <= MIN_VALUE;

        -- Otherwise, the result fits and can be returned directly.
        else
            result <= scaled_product(DATA_WIDTH - 1 downto 0);
        end if;

    end process;

end Behavioral;
