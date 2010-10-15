module RandomPassword
  # Random password generator

  # If this math is right, 15-22 characters long gives us about 128 bits of
  # randomness:
  # - 60 characters in the set; log2(60) = 5.906890596
  # - log2(60) = 5.906890596; the first 15 characters provide
  #   15 * 5.906890596 = 88.60335894 bits of randomness.
  # - the remaining 7 optional characters add log2(61) bits (5.930737338)
  #   each; 7 * 5.930737338 = 41.515161366
  # so that's 88.60335894 + 41.515161366 = 130.118520306 bits
  # (There's actually a little more since we cut the character set for
  #  each password, but I don't know how to measure that)
  MIN_PASSWORD_SIZE=15
  MAX_PASSWORD_SIZE=22

  # This character set was picked because none of the characters are
  # shell metacharacters (eg, no ~$|#\=+?, parens, quotes, etc), and will
  # be unambiguous in most fonts (so no lowercase L, capital I or O,
  # or number 0).
  PASSWORD_CHARACTERS = \
    "abcdefghijkmnopqrstuyzABCDEFGHJKLMNPQRSTUVWXYZ23456789-:.^_/"

  def self.create(options={})
    min_size = options[:min] || MIN_PASSWORD_SIZE
    max_size = options[:max] || MAX_PASSWORD_SIZE
    charset = options[:charset] || PASSWORD_CHARACTERS

    # Add randomness not directly affected by the random number generator,
    # by "cutting" the character set "deck" based on the current time.
    cut = Time.now.usec % charset.length
    charset = charset[cut..-1] + charset[0..cut]
    limit = charset.length

    # Pluck the right number of characters from random spots
    size_range = (1..(min_size + rand(max_size - min_size + 1)))
    size_range.map { charset[rand(limit), 1] }.join
  end
end