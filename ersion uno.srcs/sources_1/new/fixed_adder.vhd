
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Saturating fixed-point adder.
--
-- Default format:
--   DATA_WIDTH = 16 bits
--   FRAC_BITS  = 9 bits
--
-- If the result exceeds the representable range, clamp it
-- to the maximum or minimum signed value instead of wrapping.
--
-- FRAC_BITS is included to keep the interface consistent with
-- our library. Addition itself does not need to use it.

entity fixed_adder is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9
    );
    port (
        a   : in  signed(DATA_WIDTH - 1 downto 0);
        b   : in  signed(DATA_WIDTH - 1 downto 0);
        sum : out signed(DATA_WIDTH - 1 downto 0)
    );
end fixed_adder;

architecture Behavioral of fixed_adder is

    -- Largest positive signed number:
    -- for 16 bits, this is 0111111111111111 = 32767.
    constant MAX_VALUE : signed(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '0', others => '1');

    -- Smallest negative signed number:
    -- for 16 bits, this is 1000000000000000 = -32768.
    constant MIN_VALUE : signed(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '1', others => '0');

begin

    process(a, b)

        -- One extra bit lets us detect overflow before
        -- truncating the result to DATA_WIDTH bits.
        variable wide_sum : signed(DATA_WIDTH downto 0);

    begin

        -- Extend both operands while preserving their signs.
        wide_sum := resize(a, DATA_WIDTH + 1)
                  + resize(b, DATA_WIDTH + 1);

        -- Clamp positive overflow to the maximum value.
        if wide_sum > resize(MAX_VALUE, DATA_WIDTH + 1) then
            sum <= MAX_VALUE;

        -- Clamp negative overflow to the minimum value.
        elsif wide_sum < resize(MIN_VALUE, DATA_WIDTH + 1) then
            sum <= MIN_VALUE;

        -- Otherwise, the result is representable exactly.
        else
            sum <= wide_sum(DATA_WIDTH - 1 downto 0);
        end if;

    end process;

end Behavioral;
