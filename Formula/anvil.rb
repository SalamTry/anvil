class Anvil < Formula
  desc "Forge digital knowledge into printed study pages"
  homepage "https://github.com/SalamTry/anvil"
  url "https://github.com/SalamTry/anvil.git",
      tag:      "v1.0.0",
      revision: "HEAD"
  license "MIT"

  depends_on "pandoc"

  resource "Pillow" do
    url "https://files.pythonhosted.org/packages/cd/74/ad3d526f3bf7b6d3f408b73fde271ec69dfac8571571a005571a0e004c5d/pillow-11.1.0.tar.gz"
    sha256 "368da70808b36d73b4b390a8ffac11069f8a5c85f29eff1f1b01bcf3ef5b2a20"
  end

  def install
    # Install all anvil files into libexec
    libexec.install "anvil", "anvil-filter.lua", "sketch-page.tex", "grid-snap.lua"
    libexec.install "themes"
    libexec.install "schemes"

    # Set up Python virtualenv with Pillow for theme generators
    venv = libexec/"venv"
    system "python3", "-m", "venv", venv.to_s
    venv_pip = venv/"bin/pip"
    resource("Pillow").stage do
      system venv_pip.to_s, "install", "--no-deps", "."
    end

    # Patch theme generators to use the venv Python
    venv_python = venv/"bin/python3"
    Dir.glob(libexec/"themes/*/generate").each do |gen|
      next unless File.read(gen).start_with?("#!/usr/bin/env python3")
      inreplace gen, "#!/usr/bin/env python3", "#!#{venv_python}"
    end

    # Symlink anvil into bin — ${0:A:h} in the script resolves through
    # the symlink to libexec, finding all support files there
    bin.install_symlink libexec/"anvil"
  end

  def caveats
    <<~EOS
      anvil requires LuaLaTeX to render PDFs. Install BasicTeX:
        brew install --cask basictex

      The handwritten body font must be installed system-wide:
        Indie Flower — https://fonts.google.com/specimen/Indie+Flower

      For sketch-style d2 diagrams (optional):
        brew install d2 librsvg
    EOS
  end

  test do
    assert_match "forge digital knowledge", shell_output("#{bin}/anvil --help")

    # Full render test (requires lualatex)
    if File.exist?("/Library/TeX/texbin/lualatex") ||
       system("command", "-v", "lualatex", [:out, :err] => "/dev/null")
      output = pipe_output("#{bin}/anvil --no-print", "# Brew test\n\nHello from Homebrew.", 0)
      assert_match "Generated:", output
    end
  end
end
