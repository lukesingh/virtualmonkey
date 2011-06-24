set :runner, VirtualMonkey::Runner::MonkeySelfTest
  bla = "imanarray"
  ball = [bla, bla, bla, bla, bla ,bla, bla]
  @runner.function3(ball)
  @runner.function3(ball)
  #@runner.function3
      set = ["g1","u2","r3","u4"]
  command1 =  "probe from feature"
     @runner.probe(set,command1)
  @runner.function3(ball)
  @runner.function3(ball)
  #return "hello"     
 # @runner.function4
