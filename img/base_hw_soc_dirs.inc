\definecolor{filecolor} {rgb}{0.6,0.7,0.9}
\definecolor{dircolor}  {rgb}{0.8,0.7,0.6}

\tikzstyle{treenode} = [minimum height=3ex, anchor=north west, rounded corners=2,
                        fill opacity=0.3, draw opacity=0.4, text opacity=1,
                        inner sep=0.2ex]
\tikzstyle{dirnode}  = [treenode] %, fill=dircolor,  draw=dircolor]
\tikzstyle{filenode} = [treenode, fill=filecolor, draw=filecolor]

\tikzstyle{branch} = [draw, color=black!30!white, rounded corners=1]

\newcommand\advancelevel[1]{
	\path (anchor)+(0,-3.25ex) coordinate (anchor);

	% advance all anchors above level #1
	\foreach \i in {#1,...,10} {
		\path (anchor\i |- anchor) coordinate (anchor\i); }

	% branch to parent node
	\setcounter{decrhelper}{#1}
	\addtocounter{decrhelper}{-1}
	\path (anchor\arabic{decrhelper})+(1.5ex,-3ex) coordinate (branchfrom);
	\path (anchor#1)+(0,-1.5ex) coordinate (branchto);
	\path[branch] (branchfrom) -- (branchfrom |- branchto) -- (branchto);
}

\newcommand\dirstructure[1]{

	\foreach \i in {0,...,10} {
		\path (anchor)+(\i*3ex,0) coordinate (anchor\i); }

	%
	% lib/mk/spec/arm_v8
	%
	\advancelevel{1}
	\path (anchor1) node[dirnode] {lib/};

	\advancelevel{2}
	\path (anchor2) node[dirnode] {mk/};

	\advancelevel{3}
	\path (anchor3) node[dirnode] {spec/};

	\advancelevel{4}
	\path (anchor4) node[dirnode] {arm\_v8/};

	\advancelevel{5}
	\path (anchor5) node[filenode] {bootstrap-hw-#1.mk};

	\advancelevel{5}
	\path (anchor5) node[filenode] {core-hw-#1.mk};

	%
	% src/include/hw
	%

	\advancelevel{1}
	\path (anchor1) node[dirnode] {src/};

	\advancelevel{2}
	\path (anchor2) node[dirnode] {include/};

	\advancelevel{3}
	\path (anchor3) node[dirnode] {hw/};

	\advancelevel{4}
	\path (anchor4) node[dirnode] {spec/};

	\advancelevel{5}
	\path (anchor5) node[dirnode] {arm\_64/};

	\advancelevel{6}
	\path (anchor6) node[filenode] {#1\_board.h};

	%
	% src/bootstrap
	%

	\advancelevel{2}
	\path (anchor2) node[dirnode] {bootstrap/};

	\advancelevel{3}
	\path (anchor3) node[dirnode] {board/};

	\advancelevel{4}
	\path (anchor4) node[dirnode] {#1/};

	\advancelevel{5}
	\path (anchor5) node[filenode] {platform.cc};

	\advancelevel{5}
	\path (anchor5) node[filenode] {board.h};

	%
	% src/core
	%

	\advancelevel{2}
	\path (anchor2) node[dirnode] {core/};

	\advancelevel{3}
	\path (anchor3) node[dirnode] {board/};

	\advancelevel{4}
	\path (anchor4) node[dirnode] {#1};

	\advancelevel{5}
	\path (anchor5) node[filenode] {board.h};
}
