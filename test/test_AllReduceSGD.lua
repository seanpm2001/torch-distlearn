local test = require 'regress'
local parallel = require 'libparallel'

test {
   testAllReduceSGD = function()
      local function theTest(numEpochs, nodeIndex, numNodes, server, client, port)
         local tree = require 'parallel.Tree'(nodeIndex, numNodes, 2, server, client, '127.0.0.1', port)
         local allReduceSGD = require 'distlearn.AllReduceSGD'(tree)
         local grads = { torch.Tensor(7):fill(0) }
         local params = { torch.Tensor(7):fill(0) }
         for epoch = 1,5 do
            local steps = math.random(4, 13)
            for step = 1,steps do
               grads[1]:fill(1/steps)
               allReduceSGD.sumAndNormalizeGradients(grads)
               params[1]:add(grads[1])
            end
            allReduceSGD.synchronizeParameters(params)
         end
         return params
      end
      for _ = 1,10 do
         local numNodes = math.pow(2, math.random(1, 3))
         local numEpochs = math.random(1, 27)
         local server, port = parallel.server('127.0.0.1')
         local workers = parallel.map(numNodes - 1, function(numEpochs, numNodes, port, theTest, mapid)
            local parallel = require 'libparallel'
            local client = parallel.client('127.0.0.1', port)
            local ret = theTest(numEpochs, mapid + 1, numNodes, nil, client)
            client:close()
            return ret
         end, numEpochs, numNodes, port, theTest)
         local r1 = theTest(numEpochs, 1, numNodes, server, nil, port)
         local ret = { workers:join() }
         server:close()
         for i = 1,numNodes-1 do
            assert(torch.all(torch.eq(r1[1], ret[i][1])), 'all nodes should have identical params')
         end
      end
   end,
}