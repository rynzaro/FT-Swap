FromContract = 'WQdF4IDJvyq_Odh_Pe2FDmN9cVdjatXd4akwFOupggI'
ToContract = 'XgIYFq6hJ8OlyKJp8JbDIzYdREO5-dCfaTUhr92DeU0'
SwapContract = 'o56cFYVua1yCrfgxmuMDsxJi_QvbG4zPZBP3xrVannY'

function GetBalance(contractId)
    ao.send({
        Target = contractId,
        Action = 'Balance'
    })
end

function Transfer(contract, recipient, quantity)
    ao.send({
        Target = contract,
        Action = 'Transfer',
        Recipient = recipient,
        Quantity = quantity
    })
end

function MakeOrder(fromContract, fromAmount, toContract, toAmount)
    ao.send({
        Target = SwapContract,
        Action = 'Make-Order',
        FromContract = fromContract,
        FromAmount = fromAmount,
        ToContract = toContract,
        ToAmount = toAmount
    })
end

function TakeOrder(orderId)
    ao.send({
        Target = SwapContract,
        Action = 'Take-Order',
        OrderId = orderId
    })
end