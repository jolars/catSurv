#' Make Tree of Possible Question Combinations
#'
#' Pre-calculates a complete branching scheme of all possible questions-answer combinations and stores it as a list of lists or a flattened table of values.
#'
#' @param catObj An object of class \code{Cat}
#' @param flat A logical indicating whether to return tree as as a list of lists or a table
#'
#'
#' @details The function takes a \code{Cat} object and generates a tree of all possible question-answer combinations, conditional on previous answers in the branching scheme and the current \eqn{\theta} estimates for the branch.
#' The tree is stored as a list of lists, iteratively generated by filling in a possible answer, calculating the next question via \code{selectItem}, filling in a possible answer for that question, and so forth.
#' 
#' The length of each complete branching scheme within the tree is dictated by the \code{lengthThreshold} slot within the \code{Cat} object.
#' 
#' @return The function \code{makeTree} returns either a list or a table.  If the argument \code{flat} is \code{FALSE}, the default value, the function returns a list of lists.
#' 
#' If the argument \code{flat} is \code{TRUE}, the function takes the list of lists and configures it into a flattened table where the columns represent the battery items and the rows represent the possible answer profiles.
#' 
#' @note This function is computationally expensive.  If there are \eqn{k} response options and the researcher wants a complete branching scheme to include \eqn{n} items, \eqn{k^{n-1}} complete branching schemes will be calculated.  Setting \eqn{n} is done via the \code{lengthThreshold} slot in the \code{Cat} object.  See \strong{Examples}.
#' 
#' This function is to allow users to access the internal functions of the package. During item selection, all calculations are done in compiled \code{C++} code.
#' 
#' 
#' @seealso \code{\link{Cat-class}}, \code{\link{checkStopRules}}, \code{\link{selectItem}}
#' 
#' 
#' @examples
#' ## Loading ltm Cat object
#' data(ltm_cat)
#' 
#' ## Setting complete branches to include 3 items
#' setLengthThreshold(ltm_cat) <- 3
#' 
#' ## Object returned is list of lists
#' ltm_list <- makeTree(ltm_cat)
#' 
#' ## Object returned is table
#' ltm_table <- makeTree(ltm_cat, flat = TRUE)
#' 
#' 
#' 
#' 
#' @author Haley Acevedo, Ryden Butler, Josh W. Cutler, Matt Malis, Jacob M. Montgomery, Tom Wilkinson, Erin Rossiter, Min Hee Seo, Alex Weil 
#' 
#' @rdname makeTree
#' 
#' @export
makeTree <- function(catObj){
  UseMethod("makeTree", catObj)
}

makeTree <- function(catObj, flat = FALSE){
  var_names <- names(catObj@discrimination)
  resp_options <- rep(NA, length(var_names))
  for(i in 1:length(var_names)){
    resp_options[i] <- (length(catObj@difficulty[[i]]) + 2)
  }

  q <- selectItem(catObj)$next_item
  output <- list()
  for (i in 1:(resp_options[q])){
    output[[paste(i)]] <- NA
  }
  output[[i+1]] <- var_names[q]
  if(catObj@model == "ltm" | catObj@model == "tpm"){
    names(output) <- c(-1:(resp_options[q] - 2), "Next")
  } else {
    names(output) <- c(-1, 1:(resp_options[q] - 1), "Next")
  }
  
  ## function to be called recursively
  treeList <- function(output, catObj, var_names, resp_options){
    for(i in 1:length(output)){
      q_names <- names(output)
      
      if(is.na(output[[i]])){
        
        if(sum(is.na(catObj@answers)) == 1){
          q <- var_names[q]
          output[[q_names[i]]] <- list(Next = q)
        }
        
        if(sum(is.na(catObj@answers)) > 1 & sum(!is.na(catObj@answers)) < (catObj@lengthThreshold - 1)){
          this_q <- which(var_names == output[["Next"]])
          new_cat <- storeAnswer(catObj, this_q, as.integer(names(output)[i]))
          q <- selectItem(new_cat)$next_item
          for(j in 1:(resp_options[q] + 1)){
            output[[q_names[i]]][[j]] <- NA
          }
          output[[q_names[i]]][[j]] <- var_names[q]
          if(catObj@model == "ltm" | catObj@model == "tpm"){
            names(output[[q_names[i]]]) <- c(-1:(resp_options[q]-2), "Next")
          }else{
            names(output[[q_names[i]]]) <- c(-1, 1:(resp_options[q]-1), "Next")
          }
          output[[q_names[i]]] <- as.list(output[[q_names[i]]])

          ## calling it recursively
          output[[q_names[i]]] <- treeList(output = output[[q_names[i]]],
                                     catObj = new_cat,
                                     var_names = var_names,
                                     resp_options = resp_options)
        }
        
        if(sum(!is.na(catObj@answers)) >= (catObj@lengthThreshold-1)){
          this_q <- which(var_names == output[["Next"]])
          new_cat <- storeAnswer(catObj, this_q, as.integer(names(output)[i]))
          q <- selectItem(new_cat)$next_item
          q <- var_names[q]
          output[[q_names[i]]] <- list(Next = q)
        }
      }
    }
    return(output)
  }
  
  ## calling recursive function
  tree <- treeList(output, catObj, var_names = var_names, resp_options = resp_options)
  
  ## flatten the tree or leave it as list of lists
  if(flat == FALSE){
    out <- tree
  }else{
    flattenTree <- function(tree){
      flatTree <- unlist(tree)
      names(flatTree) <- gsub("Next", "", names(flatTree))
      flatTree <- flatTree[order(nchar(names(flatTree)))]
      
      if(catObj@model == "ltm" | catObj@model == "tpm"){
        ans_choices <- c("-", 0:(resp_options[1] - 2))
      } else {
        ans_choices <- c("-", 1:(resp_options[1] - 1))
      }
      
      orderedTree <- flatTree[1]
      for(i in ans_choices[1:length(ans_choices)]){
        answers <- rep(NA, (length(flatTree)-1)/length(ans_choices))
        answers <- flatTree[substring(names(flatTree), 1, 1) == i]
        orderedTree <- c(orderedTree, answers)
      }
      
      flatTree <- orderedTree
      
      response_list <- strsplit(names(flatTree), "[.]")
      output <- matrix(data = NA, nrow = length(flatTree), ncol = length(catObj@answers) + 1)
      colnames(output) <- c(names(catObj@difficulty), "NextItem")
      
      for(i in 1:length(flatTree)){
        output[i,ncol(output)] <- flatTree[i]
        if(i > 1){ 
          output[i, output[1, ncol(output)]] <- response_list[[i]][1]
          if(length(response_list[[i]]) > 1){
            for(j in 1:(length(response_list[[i]])-1)){
              output[i, flatTree[which(sapply(1:length(response_list), function(f)
                identical(response_list[[f]], response_list[[i]][1:j])))]]  <- response_list[[i]][j+1]
            }
          }
        }
      }
      output <- as.table(as.matrix(output))
      return(output)
    }
    out <- flattenTree(tree)
  }
  return(out)
}

