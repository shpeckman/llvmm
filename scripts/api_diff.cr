# scripts/api_diff.cr
require "http/client"
require "json"
require "uri"

HEADERS = [
  "Core.h", "Target.h", "TargetMachine.h", "Orc.h", "LLJIT.h",
  "Analysis.h", "BitReader.h", "BitWriter.h", "DebugInfo.h",
  "IRReader.h", "Support.h", "Error.h", "Types.h", "ExecutionEngine.h",
  "Transforms/PassBuilder.h", "Object.h", "Disassembler.h",
]

SKIP_SYMBOLS = Set{"LLVM_C_ABI", "LLVMBool"}

GITHUB = URI.parse("https://api.github.com")
RAW    = "https://raw.githubusercontent.com/llvm/llvm-project"

def raw_base : String
  if proxy = ENV["GH_PROXY"]?
    "#{proxy}/#{RAW}"
  else
    RAW
  end
end

def http_get(uri : URI) : String
  headers  = HTTP::Headers{"User-Agent" => "llvmm-api_diff"}
  response = HTTP::Client.get(uri, headers: headers)
  raise "GET #{uri} -> #{response.status_code}" unless response.success?
  response.body
end

tag = ARGV[0]? || begin
  if ENV["GH_PROXY"]?
    STDERR.puts "GH_PROXY is set; pass the llvmorg tag explicitly (GitHub API is not proxied)"
    exit 1
  end
  release = JSON.parse(http_get(URI.parse("#{GITHUB}/repos/llvm/llvm-project/releases/latest")))
  release["tag_name"].as_s
end

unless tag =~ /\Allvmorg-(\d+)\./
  STDERR.puts "Unexpected tag: #{tag}"
  exit 1
end
tag_major = $1.to_i

declared = Set(String).new
HEADERS.each do |header|
  begin
    body = http_get(URI.parse("#{raw_base}/#{tag}/llvm/include/llvm-c/#{header}"))
  rescue
    next
  end
  body.scan(/\b(LLVM[A-Za-z0-9_]+)\s*\(/) do |match|
    name = match[1]
    next if SKIP_SYMBOLS.includes?(name)
    next if name.ends_with?("Ref")
    next unless name[4..].matches?(/[a-z]/)
    declared << name
  end
end

alias Gate = Tuple(Symbol, Int32)

def visible_at?(gates : Array(Gate), major : Int32) : Bool
  gates.all? do |op, ver|
    op == :unless ? major >= ver : major < ver
  end
end

bound = {} of String => Array(Gate)
Dir.glob(File.join(__DIR__, "..", "src", "llvmm", "lib_llvm", "**", "*.cr")).each do |file|
  gates = [] of Gate
  File.each_line(file) do |line|
    case line
    when /\{%\s*(unless|if)\s+LibLLVMM::IS_LT_(\d+)0\s*%\}/
      gates << {$1 == "unless" ? :unless : :if, $2.to_i}
    when /\{%\s*else\s*%\}/
      gates[-1] = {gates[-1][0] == :unless ? :if : :unless, gates[-1][1]} unless gates.empty?
    when /\{%\s*end\s*%\}/
      gates.pop?
    when /fun\s+\w+\s*=\s*(LLVM[A-Za-z0-9_]+)\b/
      bound[$1] = gates.dup unless line.includes?("{{")
    end
  end
end

unbound  = (declared - bound.keys).to_a.sort
vanished = bound.select { |name, gates| !declared.includes?(name) && visible_at?(gates, tag_major) }.keys.sort
gated    = bound.select { |name, gates| !declared.includes?(name) && !visible_at?(gates, tag_major) }.keys.sort

puts "Release: #{tag} (#{declared.size} symbols declared, #{bound.size} bound)"

puts "\nUnbound (#{unbound.size}):"
unbound.each { |name| puts "  #{name}" }

puts "\nVanished at this tag (#{vanished.size}):"
vanished.each { |name| puts "  #{name}" }

puts "\nVanished but version-gated away (#{gated.size}):"
gated.each { |name| puts "  #{name}" }

exit(vanished.empty? ? 0 : 1)
