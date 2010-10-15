require 'erb'

module FileTemplate
  def process_template(template, variables=nil)
    # Process a template file with ERB, with these variables,
    # and return the result
    # (This is a hacky way of passing a limited set of variables to
    # ERB: it only works because #inspect generally does what we need
    # for strings and numbers)
    template = RelativePath.find(template)
    context = Proc.new do
      ERB.new(File.open(template) {|f| f.read }).result binding
    end
    eval(variables.map {|k, v| "#{k} = #{v.inspect}"}.join('; '), context) \
      if variables.is_a? Hash
    context.call
  end

  def copy_from_template(template, destination, variables=nil)
    output = process_template(template, variables)
    File.open(destination, 'w') {|f| f.write(output) }
  end
end
