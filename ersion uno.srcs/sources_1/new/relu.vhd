
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ReLU activation function for our fixed-point AI library.
--
-- ReLU(x) = max(0, x)
--
-- The input and output use the same signed fixed-point format.
-- ReLU does not need to know FRAC_BITS because it only checks
-- whether the number is negative. Zero has the same representation
-- in every fixed-point format.

entity relu is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9
    );
    port (
        x      : in  signed(DATA_WIDTH - 1 downto 0);
        result : out signed(DATA_WIDTH - 1 downto 0)
    );
end relu;

architecture Behavioral of relu is
begin

    process(x)
    begin
        -- Negative inputs produce zero.
        if x < to_signed(0, DATA_WIDTH) then
            result <= (others => '0');

        -- Zero and positive inputs pass through unchanged.
        else
            result <= x;
        end if;
    end process;

end Behavioral;
