
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Multiply-accumulate (MAC) unit for our AI hardware library.
--
-- Operation:
--   accumulator_next = accumulator + (a * b) / 2**FRAC_BITS
--
-- Inputs use DATA_WIDTH-bit signed fixed-point numbers.
-- The accumulator uses ACC_WIDTH bits with the SAME number
-- of fractional bits as the inputs.
--
-- The accumulator is wider to reduce overflow during summation.
-- This unit is combinational: it does not store state internally.

entity fixed_mac is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        ACC_WIDTH  : positive := 32
    );
    port (
        a           : in  signed(DATA_WIDTH - 1 downto 0);
        b           : in  signed(DATA_WIDTH - 1 downto 0);
        accumulator : in  signed(ACC_WIDTH - 1 downto 0);
        result      : out signed(ACC_WIDTH - 1 downto 0)
    );
end fixed_mac;

architecture Behavioral of fixed_mac is

    -- Full multiplication result: twice the input width.
    signal full_product :
        signed((2 * DATA_WIDTH) - 1 downto 0);

    -- Product rescaled to the original fractional precision.
    signal scaled_product :
        signed((2 * DATA_WIDTH) - 1 downto 0);

    -- Extend the product to the accumulator width.
    signal product_extended :
        signed(ACC_WIDTH - 1 downto 0);

begin

    -- Multiply the inputs.
    full_product <= a * b;

    -- Restore the fixed-point scale.
    scaled_product <= shift_right(full_product, FRAC_BITS);

    -- Convert the product to the accumulator width.
    product_extended <= resize(scaled_product, ACC_WIDTH);

    -- Add the product to the running sum.
    -- Saturation is handled in the next version of this component.
    result <= accumulator + product_extended;

end Behavioral;
