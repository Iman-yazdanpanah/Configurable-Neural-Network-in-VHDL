
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lfsr_random is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9
    );
    port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;

        -- Load a seed to start a reproducible sequence.
        seed_load : in STD_LOGIC;
        seed      : in STD_LOGIC_VECTOR(15 downto 0);

        -- Advance the generator when enable is high.
        enable : in STD_LOGIC;

        -- Pseudo-random signed fixed-point output.
        random_value : out SIGNED(DATA_WIDTH - 1 downto 0)
    );
end lfsr_random;

architecture Behavioral of lfsr_random is

    signal lfsr : STD_LOGIC_VECTOR(15 downto 0)
        := x"ACE1";

begin

    process(clk, reset)
        variable feedback : STD_LOGIC;
    begin
        if reset = '1' then
            lfsr <= x"ACE1";

        elsif rising_edge(clk) then

            if seed_load = '1' then
                -- An all-zero LFSR state would never change.
                if seed = x"0000" then
                    lfsr <= x"ACE1";
                else
                    lfsr <= seed;
                end if;

            elsif enable = '1' then
                -- Feedback taps for a 16-bit LFSR.
                feedback := lfsr(15) xor lfsr(13)
                                      xor lfsr(12) xor lfsr(10);

                lfsr <= lfsr(14 downto 0) & feedback;
            end if;

        end if;
    end process;

    -- Interpret the lowest 8 bits as a signed value.
    -- Sign-extend it to DATA_WIDTH.
    --
    -- With DATA_WIDTH=16 and FRAC_BITS=9:
    -- output range = -128/512 to 127/512
    --              = -0.25 to approximately +0.248
    random_value <= resize(signed(lfsr(7 downto 0)), DATA_WIDTH);

end Behavioral;
