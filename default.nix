{ lib, stdenv, fetchFromGitHub, makeWrapper, bash, tmux, fzf }:

stdenv.mkDerivation rec {
  pname = "tmuxer";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "szcharlesji";
    repo = "tmuxer";
    rev = "v${version}";  # Use a tag like v0.1.0, or "main" for latest
    sha256 = "sha256-64PdEFCzLyzWvzyr3CU/RoXX9fW3w6G/A/9DKBPt9Mg=";
  };
  
  nativeBuildInputs = [ makeWrapper ];
  
  installPhase = ''
    mkdir -p $out/bin
    cp $src/tmuxer.sh $out/bin/tmuxer
    chmod +x $out/bin/tmuxer
    ln -s $out/bin/tmuxer $out/bin/tmr
    
    wrapProgram $out/bin/tmuxer \
      --prefix PATH : ${lib.makeBinPath [ bash tmux fzf ]}
  '';

  meta = with lib; {
    description = "A tmux session starter with predefined layouts";
    homepage = "https://github.com/szcharlesji/tmuxer";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.unix;
  };
}
