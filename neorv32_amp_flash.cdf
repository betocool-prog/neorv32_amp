/* Quartus Prime Version 21.1.0 Build 842 10/21/2021 SJ Lite Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Cfg)
		Device PartName(EP4CE22) Path("./output_files/") File("neorv32_amp.jic") MfrSpec(OpMask(1) SEC_Device(EPCS64) Child_OpMask(1 1));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
