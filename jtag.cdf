JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Ign)
		Device PartName(SOCVHPS) MfrSpec(OpMask(0));
	P ActionCode(Cfg)
		Device PartName(5CSEBA6U23I7) Path("output_files/") File("Arcade-XSleenaCore_120SDR_ONLY_TILES.sof") MfrSpec(OpMask(1));
ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
