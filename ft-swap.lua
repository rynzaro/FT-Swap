---@diagnostic disable: undefined-global, undefined-field
local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')

Balances = Balances or {}
OpenOrders = OpenOrders or {}
CurrentId = CurrentId or 0

Handlers.add(
    'receiveDeposit',
    Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
    function(msg)
        local depositContractId = msg.From
        local sender = msg.Tags.Sender
        local quantity = bint(msg.Tags.Quantity)

        if not Balances[depositContractId] then
            --if contract ID has n record, create it
            print('Register Contract ID')
            Balances[depositContractId] = {[sender] = tostring(quantity)}
        else
            if not Balances[depositContractId][sender] then
                print('Sender is depositing this currency for the first time')
                Balances[depositContractId][sender] = tostring(quantity)
            else
                print('Updating deposit for existing sender.')
                Balances[depositContractId][sender] = tostring(bint.__add(quantity, bint(Balances[depositContractId][sender])))
            end
        end
        ao.send({
            Target = msg.Tags.Sender,
            Action = 'Deposit-Notice',
            Data = 'Succesfully deposited ' .. tostring(quantity) .. ' tokens from fungible token process ' .. msg.From,
            Balance = tostring(Balances[depositContractId][sender])
        })
    end
)

Handlers.add(
    'receiveMake',
    Handlers.utils.hasMatchingTag('Action', 'Make-Order'),
    function(msg)
        assert(type(msg.FromContract) == 'string', 'Need to input contract address to exchange from!')
        assert(type(msg.ToContract) == 'string', 'Need to input contract address to exchange to!')
        assert(type(msg.FromAmount) == 'string', 'Need to input amount to exchange from!')
        assert(type(msg.ToAmount) == 'string', 'Need to input amount to exchange to!')

        -- we wanna handle that through an error message
        local makerBalance = bint(Balances[msg.FromContract][msg.From])
        local fromAmount = bint(msg.FromAmount)

        if bint.__lt(makerBalance, fromAmount) then
            ao.send({
                Target = msg.From,
                Action = 'Make-Order-Error',
                Data = 'Balance to low for order creation. Balance ' .. Balances[msg.FromContract][msg.From] .. ', Quantity needed ' .. msg.FromAmount,
            })
            return
        elseif not Balances[msg.FromContract][msg.From] then
            ao.send({
                Target = msg.From,
                Action = 'Make-Order-Error',
                Data = 'Maker does not have a registered balance',
            })
            return
        end

        local order = {
            OrderId = CurrentId,
            Maker = msg.From,
            FromContract = msg.FromContract,
            ToContract = msg.ToContract,
            FromAmount = msg.FromAmount,
            ToAmount = msg.ToAmount,
        }

        Balances[msg.FromContract][msg.From] = tostring(bint.__sub(makerBalance, fromAmount))

        OpenOrders[CurrentId] = order
        CurrentId = CurrentId + 1;
        ao.send({
            Target = msg.From,
            Action = 'Make-Order-Success',
            Data = 'Succesfully create an order with the id ' .. order.OrderId,
            Balance = Balances[msg.FromContract][msg.From],
        })
    end
)

Handlers.add(
    'receiveTake',
    Handlers.utils.hasMatchingTag('Action', 'Take-Order'),
    function(msg)
        assert(type(msg.OrderId) == 'string', 'Need to input OrderId')
        local id = tonumber(msg.OrderId)
        -- assign Order to a local order variable
        local order = OpenOrders[id]

        if not order then
            ao.send({
                Target = msg.From,
                Action = 'Take-Order-Error',
                Data = 'ERROR: Order does not exist or has already been completed',
            })
            return
        end

        local toAmount = bint(order.ToAmount)
        local taker = msg.From

        -- check if taker balance is high enough
        local takerBalance = bint(Balances[order.ToContract][taker])
        if not bint.__le(toAmount, takerBalance) then
            ao.send({
                Target = msg.From,
                Action = 'Take-Order-Error',
                Data = 'ERROR: Balance is too low. Balance: ' .. Balances[order.ToContract][taker] .. ', Quantity needed: ' .. order.ToAmount,
            })
            return
        end
        -- if balance is high enough, deduct amount from the balance
        Balances[order.ToContract][taker] = tostring(bint.__sub(takerBalance, toAmount))

        -- send maker's deposit to taker
        ao.send({
            Target = order.ToContract,
            Action = 'Transfer',
            Recipient = order.Maker,
            Quantity = order.ToAmount,
        })

        -- send notification to taker
        ao.send({
            Target = msg.From,
            Action = 'Take-Order-Success',
            Balance = Balances[order.ToContract][taker]
        })

        -- send taker's deposit to maker
        ao.send({
            Target = order.FromContract,
            Action = 'Transfer',
            Recipient = msg.From,
            Quantity = order.FromAmount,
        })
        -- delete order from the open order array
        OpenOrders[id] = nil
    end
)

Handlers.add(
    'orderInfo',
    Handlers.utils.hasMatchingTag('Action', 'Order-Info'),
    function(msg)
        assert(type(msg.OrderId) == 'string', 'You need to input an Order ID')
        local orderId = tonumber(msg.OrderId)
        if (orderId >= CurrentId) then
            ao.send({
                Target = msg.From,
                Action = 'Order-Info-Error',
                Data = 'Order ID does not exist'
            })
        elseif not OpenOrders[orderId] then
            ao.send({
                Target = msg.From,
                Action = 'Order-Info-Error',
                Data = 'Order already completed'
            })
        else
            local order = OpenOrders[orderId]
            ao.send({
                Target = msg.From,
                Action = 'Order-Info-Success',
                OrderId = tostring(order.OrderId),
                FromContract = order.FromContract,
                ToContract = order.ToContract,
                FromAmount = order.FromAmount,
                ToAmount = order.ToAmount,
            })
        end
    end
)

Handlers.add(
    'printOrders',
    Handlers.utils.hasMatchingTag('Action', 'Print-Orders'),
    function(msg)
        for key, order in pairs(OpenOrders) do
            print(order)
        end
    end

)