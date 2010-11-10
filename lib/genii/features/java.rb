class Features::Java < Feature
  def create_dependencies
    depends_on :packages => {
                 :names => %w[default-jdk]
               }
  end
end