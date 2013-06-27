# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :rspec, cli: '-f progress -f Nc', env: { 'NO_SIMPLECOV' => '1' } do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(tkellem/)?(.+)\.rb$})     { |m| "spec/#{m[2]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
end

